`timescale 1ns / 1ps

module tb_async_fifo;

    // signals
    logic reset = 0;
    logic wclk, rclk;
    logic write_enable, read_enable;
    logic [4:0] fifo_occu_in;
    logic [4:0] fifo_occu_out;
    logic [7:0] write_data_in;
    logic [7:0] read_data_out;

    // parameters
    localparam DATA_W       = 8;
    localparam DEPTH        = 16;

    // clock generation
    initial begin
        wclk = 0;
        forever #5 wclk = ~wclk;  // 100 MHz (number is half-period)
    end

    initial begin
        rclk = 0;
        forever #7 rclk = ~rclk;  // ~71 MHz
    end

    // device under test
    async_fifo DUT (
        .reset         (reset),
        .wclk          (wclk),
        .rclk          (rclk),
        .write_enable  (write_enable),
        .read_enable   (read_enable),
        .fifo_occu_in  (fifo_occu_in),
        .fifo_occu_out (fifo_occu_out),
        .write_data_in (write_data_in),
        .read_data_out (read_data_out)
    );

    int pass_count = 0;
    int fail_count = 0;

    task check(
        input string    label,
        input logic [7:0] got,
        input logic [7:0] expected
    );
        if (got === expected) begin
            $display("  PASS  %s : got 0x%02h", label, got);
            pass_count++;
        end else begin
            $display("  FAIL  %s : got 0x%02h  expected 0x%02h", label, got, expected);
            fail_count++;
        end
    endtask

    task check_int(
        input string label,
        input int    got,
        input int    expected
    );
        if (got === expected) begin
            $display("  PASS  %s : got %0d", label, got);
            pass_count++;
        end else begin
            $display("  FAIL  %s : got %0d  expected %0d", label, got, expected);
            fail_count++;
        end
    endtask

    // stimulus
    initial begin

        // --- initialise
        reset = 1; write_enable = 0; read_enable = 0; write_data_in = 0;

        // test 1: reset behaviour (expect occupancy 0 on both)
        $display("\n test 1: reset behaviour");
        repeat(4) @(posedge wclk);
        reset = 0;
        @(posedge wclk);
        check_int("occu_in  after reset", int'(fifo_occu_in),  0);
        check_int("occu_out after reset", int'(fifo_occu_out), 0);

        // test 2: write 4 words and then read back (expect: AA,BB,CC,DD)
        $display("\n test 2: write 4 words");
        write_enable = 1;
        write_data_in = 8'hAA; @(posedge wclk);
        write_data_in = 8'hBB; @(posedge wclk);
        write_data_in = 8'hCC; @(posedge wclk);
        write_data_in = 8'hDD; @(posedge wclk);
        write_enable = 0;
        $display("  occu_in after 4 writes = %0d (expect ~4)", fifo_occu_in);

        repeat(6) @(posedge rclk);  // let synchronizer catch up

        read_enable = 1;
        @(posedge rclk);   // rptr moves, address presented
        @(posedge rclk);   // RAM address register latches
        @(posedge rclk);   // RAM output register fires → AA valid NOW
        check("read[0]", read_data_out, 8'hAA);
        @(posedge rclk);
        check("read[1]", read_data_out, 8'hBB);
        @(posedge rclk);
        check("read[2]", read_data_out, 8'hCC);
        @(posedge rclk);
        check("read[3]", read_data_out, 8'hDD);
        read_enable = 0;
        repeat(4) @(posedge rclk);

        // test 3: fill fifo completely, expecth 17th write ignored
        $display("\n test 3: fill fifo completely");
        write_enable = 1;
        for (int i = 0; i < 16; i++) begin
            write_data_in = i[7:0];
            @(posedge wclk);
        end
        write_enable = 0;
        @(posedge wclk);
        check_int("occu_in after 16 writes", int'(fifo_occu_in), 16);

        // try illegal 17th write
        write_enable = 1; write_data_in = 8'hFF;
        @(posedge wclk);
        write_enable = 0;
        @(posedge wclk);
        check_int("occu_in after illegal write (expect 16)", int'(fifo_occu_in), 16);

        // test 4: drain FIFO completely (16 reads)
        $display("\n test 4: drain fifo (16 reads)");
        repeat(6) @(posedge rclk);  // synchronizer catch-up
        read_enable = 1;
        @(posedge rclk);   // rptr moves
        @(posedge rclk);   // RAM address latched
        for (int i = 0; i < 16; i++) begin
            @(posedge rclk);
            check($sformatf("drain[%0d]", i), read_data_out, i[7:0]);
        end
        read_enable = 0;
        repeat(6) @(posedge rclk);
        check_int("occu_out after full drain", int'(fifo_occu_out), 0);

        // illegal read on empty — rptr must not move
        $display("  Attempting read on empty FIFO...");
        read_enable = 1; @(posedge rclk);
        read_enable = 0; @(posedge rclk);
        check_int("occu_out after illegal read (expect 0)", int'(fifo_occu_out), 0);

        // test 5: pointer wrap-around, write 20 words, wptr wraps past 16
        $display("\n test 5: wptr wrap around");

        // write 16 to fill it
        write_enable = 1;
        for (int i = 0; i < 16; i++) begin
            write_data_in = 8'hA0 + i[7:0];
            @(posedge wclk);
        end
        write_enable = 0;

        // read all 16 out
        repeat(6) @(posedge rclk);
        read_enable = 1;
        @(posedge rclk);
        for (int i = 0; i < 16; i++) @(posedge rclk);
        read_enable = 0;
        repeat(4) @(posedge rclk);

        // now write 4 more — wptr has wrapped past 16, tests the wrap
        write_enable = 1;
        for (int i = 16; i < 20; i++) begin
            write_data_in = 8'hA0 + i[7:0];
            @(posedge wclk);
        end
        write_enable = 0;

        // read those 4 back and verify
        repeat(6) @(posedge rclk);
        read_enable = 1;
        @(posedge rclk);   // rptr moves
        @(posedge rclk);   // RAM address latched
        for (int i = 16; i < 20; i++) begin
            @(posedge rclk);
            check($sformatf("wrap[%0d]", i), read_data_out, 8'hA0 + i[7:0]);
        end
        read_enable = 0;
        repeat(4) @(posedge rclk);

        // test 6: simultaneous read and write
        $display("\n test 6: simultaneous read and write");
        repeat(2) @(posedge wclk);
        write_enable = 1;
        read_enable  = 1;
        for (int i = 0; i < 32; i++) begin
            write_data_in = 8'hC0 + i[7:0];
            @(posedge wclk);
        end
        write_enable = 0;

        // drain whatever is left
        repeat(20) @(posedge rclk);  // generous wait for synchronizer
        read_enable = 0;

        // now wait for synchronizer to settle and check
        repeat(8) @(posedge rclk);
        check_int("occu_out after simultaneous R/W drain", int'(fifo_occu_out), 0);

        // summary
        repeat(4) @(posedge wclk);
        $display("  results: %0d passed,  %0d failed", pass_count, fail_count);
        $finish;
    end

endmodule