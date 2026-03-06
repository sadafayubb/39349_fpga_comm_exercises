module async_fifo #(
    parameter DATA_W = 8,
    parameter DEPTH  = 16
)(
    input  logic                  reset,
    input  logic                  wclk,
    input  logic                  rclk,
    input  logic                  write_enable,
    input  logic                  read_enable,
    output logic [$clog2(DEPTH):0] fifo_occu_in,   // spot avaliable for write
    output logic [$clog2(DEPTH):0] fifo_occu_out,   // spots avaliable for read
    input  logic [DATA_W-1:0]     write_data_in,
    output logic [DATA_W-1:0]     read_data_out
);

    localparam PTR_W = $clog2(DEPTH) + 1;  // 5 bits for DEPTH=16

    // pointers
    logic [PTR_W-1:0] wptr, rptr;

    // gray code signals
    logic [PTR_W-1:0] wptr_gray, rptr_gray;
    logic [PTR_W-1:0] wptr_gray_ff1, wptr_gray_ff2, wptr_gray_ff3;
    logic [PTR_W-1:0] rptr_gray_ff1, rptr_gray_ff2, rptr_gray_ff3;
    logic [PTR_W-1:0] wptr_sync, rptr_sync;

    logic full, empty;

    // binary to gray conversion
    assign wptr_gray = wptr ^ (wptr >> 1);
    assign rptr_gray = rptr ^ (rptr >> 1);

    // gray to binary 
    function automatic [PTR_W-1:0] gray_to_bin(input [PTR_W-1:0] gray);
        logic [PTR_W-1:0] bin;
        bin[PTR_W-1] = gray[PTR_W-1];
        for (int i = PTR_W-2; i >= 0; i--)
            bin[i] = bin[i+1] ^ gray[i];
        return bin;
    endfunction

    assign wptr_sync = gray_to_bin(wptr_gray_ff3);
    assign rptr_sync = gray_to_bin(rptr_gray_ff3);

    // synchronizers (wptr crosses into rclk domain) (rptr crosses into wclk domain)
    // wptr FF1 — source domain (wclk)
    always_ff @(posedge wclk or posedge reset)
        if (reset) wptr_gray_ff1 <= '0;
        else        wptr_gray_ff1 <= wptr_gray;

    // wptr FF2+FF3 — destination domain (rclk)
    always_ff @(posedge rclk or posedge reset)
        if (reset) begin wptr_gray_ff2 <= '0; wptr_gray_ff3 <= '0; end
        else       begin wptr_gray_ff2 <= wptr_gray_ff1; wptr_gray_ff3 <= wptr_gray_ff2; end

    // rptr FF1 — source domain (rclk)
    always_ff @(posedge rclk or posedge reset)
        if (reset) rptr_gray_ff1 <= '0;
        else        rptr_gray_ff1 <= rptr_gray;

    // rptr FF2+FF3 — destination domain (wclk)
    always_ff @(posedge wclk or posedge reset)
        if (reset) begin rptr_gray_ff2 <= '0; rptr_gray_ff3 <= '0; end
        else       begin rptr_gray_ff2 <= rptr_gray_ff1; rptr_gray_ff3 <= rptr_gray_ff2; end

    // memory 
    logic [PTR_W-2:0] waddr, raddr;
    assign waddr = wptr[PTR_W-2:0];
    assign raddr = rptr[PTR_W-2:0];

     mem mem_inst (
        .data ( write_data_in ),
        .rdaddress (raddr),
        .rdclock ( rclk ),
        .wraddress ( waddr ),
        .wrclock ( wclk ),
        .wren ( write_enable & !full),
        .q ( read_data_out )
    );

    // full and empty flags
    assign full  = (wptr[PTR_W-1]     != rptr_sync[PTR_W-1]) &&
                    (wptr[PTR_W-2:0]   == rptr_sync[PTR_W-2:0]);

    assign empty = (wptr_sync == rptr);

    // occupancy
    assign fifo_occu_in  = wptr - rptr_sync;  // write-side view
    assign fifo_occu_out = wptr_sync - rptr;   // read-side  view

    // write logic (wclk)
    always_ff @(posedge wclk or posedge reset) begin
        if (reset)
            wptr <= '0;
        else if (write_enable && !full) begin
            wptr <= wptr + 1'b1;
        end
    end

    // read logic (rclk)
    always_ff @(posedge rclk or posedge reset) begin
        if (reset) begin
            rptr          <= '0;
        end else if (read_enable && !empty) begin
            rptr          <= rptr + 1'b1;
        end
    end

endmodule