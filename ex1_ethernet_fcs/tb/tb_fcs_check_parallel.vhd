library ieee;
use ieee.std_logic_1164.all;

entity tb_fcs_check_parallel is
end tb_fcs_check_parallel;

architecture sim of tb_fcs_check_parallel is
    component fcs_check_parallel is
        port (
            clk : in std_logic; -- system clock
            reset : in std_logic; -- asynchronous reset
            start_of_frame : in std_logic; -- arrival of the first bit.
            end_of_frame : in std_logic; -- arrival of the first bit in FCS.
            data_in : in std_logic_vector(7 downto 0); -- input data.
            fcs_error : out std_logic -- indicates an error.
        );
    end component;

    -- local signals
    signal clk : std_logic := '0';
    signal reset : std_logic := '0';
    signal start_of_frame : std_logic := '0';
    signal end_of_frame : std_logic := '0';
    signal data_in : std_logic_vector(7 downto 0) := (others => '0');
    signal fcs_error : std_logic;

    constant CLK_PERIOD : time := 10 ns;

    type byte_array is array (natural range <>) of std_logic_vector(7 downto 0);
    
    constant PACKET : byte_array := (
        -- Destination Address
        -- x"FF", x"EF", x"5B", x"84", -- first 32 bits
        x"00", x"10", x"A4", x"7B", -- first 32 bits
        x"EA", x"80",
        -- Source Address
        x"00", x"12", x"34", x"56", x"78", x"90",
        -- Length/Type
        x"08", x"00",
        -- Data
        x"45", x"00", x"00", x"2E", x"B3", x"FE", x"00", x"00",
        x"80", x"11", x"05", x"40", x"C0", x"A8", x"00", x"2C",
        x"C0", x"A8", x"00", x"04", x"04", x"00", x"04", x"00",
        x"00", x"1A", x"2D", x"E8", x"00", x"01", x"02", x"03",
        x"04", x"05", x"06", x"07", x"08", x"09", x"0A", x"0B",
        x"0C", x"0D", x"0E", x"0F", x"10", x"11",
        -- FCS (last 4 bytes)
        -- x"19", x"3A", x"C2", x"4D"
        x"E6", x"C5", x"3D", x"B2"
    );
    
    constant CORRUPTED_PACKET : byte_array := (
        -- Destination Address
        -- x"FF", x"EF", x"5B", x"84", -- first 32 bits
        x"00", x"10", x"A4", x"7B", -- first 32 bits
        x"EA", x"80",
        -- Source Address
        x"00", x"12", x"34", x"56", x"78", x"90",
        -- Length/Type
        x"08", x"FF", -- inverted last byte
        -- Data
        x"45", x"00", x"00", x"2E", x"B3", x"FE", x"00", x"00",
        x"80", x"11", x"05", x"40", x"C0", x"A8", x"00", x"2C",
        x"C0", x"A8", x"00", x"04", x"04", x"00", x"04", x"00",
        x"00", x"1A", x"2D", x"E8", x"00", x"01", x"02", x"03",
        x"04", x"05", x"06", x"07", x"08", x"09", x"0A", x"0B",
        x"0C", x"0D", x"0E", x"0F", x"10", x"11",
        -- FCS (last 4 bytes)
        -- x"19", x"3A", x"C2", x"4D"
        x"E6", x"C5", x"3D", x"B2"
    );
    
    constant FCS_START : integer := PACKET'length - 4;

    procedure send_byte (
        constant byte_val : in std_logic_vector(7 downto 0);
        signal   data_out : out std_logic_vector(7 downto 0);
        signal   clk_sig  : in  std_logic
    ) is
    begin
        data_out <= byte_val;
        wait until rising_edge(clk_sig);
    end procedure;

begin
    DUT: fcs_check_parallel
        port map (
            clk => clk,
            reset => reset,
            start_of_frame => start_of_frame,
            end_of_frame => end_of_frame,
            data_in => data_in,
            fcs_error => fcs_error
        );
    
    clk <= not clk after CLK_PERIOD / 2;

    stimulus: process
    begin
        -- reset
        reset <= '1';
        wait for CLK_PERIOD;
        wait until rising_edge(clk);
        reset <= '0';

        start_of_frame <= '1';

        -- send all the bytes of frame, including FCS
        for byte_index in PACKET'range loop
            -- assert end_of_frame on first bit of FCS
            if byte_index = FCS_START then
                end_of_frame <= '1';
            end if;

            send_byte(PACKET(byte_index), data_in, clk);

            -- deassert start_of_frame after sending the first byte of packet
            if byte_index = 0 then
                start_of_frame <= '0';
            end if;

            -- deassert end_of_frame after sending the first byte of FCS
            if byte_index = FCS_START then
                end_of_frame <= '0';
            end if;
        
        end loop;

        wait for 2*CLK_PERIOD;

        -- Check result
        if fcs_error = '0' then
            report "TEST 1 PASSED: No FCS error detected (correct!)";
        else
            report "TEST 1 FAILED: FCS error incorrectly raised!" severity error;
        end if;

        wait for 5 * CLK_PERIOD;

        -- reset
        reset <= '1';
        wait for CLK_PERIOD;
        wait until rising_edge(clk);
        reset <= '0';

        start_of_frame <= '1';

        -- send all the bytes of frame, including FCS
        for byte_index in CORRUPTED_PACKET'range loop
            -- assert end_of_frame on first bit of FCS
            if byte_index = FCS_START then
                end_of_frame <= '1';
            end if;

            send_byte(CORRUPTED_PACKET(byte_index), data_in, clk);

            -- deassert start_of_frame after sending the first byte of packet
            if byte_index = 0 then
                start_of_frame <= '0';
            end if;

            -- deassert end_of_frame after sending the first byte of FCS
            if byte_index = FCS_START then
                end_of_frame <= '0';
            end if;
        
        end loop;

        wait for 2*CLK_PERIOD;

        -- Check result
        if fcs_error = '1' then
            report "TEST 2 PASSED: Invalid packet raised error (correct!)";
        else
            report "TEST 2 FAILED: FCS error wasn't raised for invalid packet!" severity error;
        end if;

        -- Done
        wait for 5 * CLK_PERIOD;
        report "Simulation complete.";
        wait;

    end process;

end sim;