library ieee;
use ieee.std_logic_1164.all;

entity fcs_check_serial is
    port (
        clk : in std_logic; -- system clock
        reset : in std_logic; -- asynchronous reset
        start_of_frame : in std_logic; -- arrival of the first bit.
        end_of_frame : in std_logic; -- arrival of the first bit in FCS.
        data_in : in std_logic; -- serial input data.
        fcs_error : out std_logic -- indicates an error.
    );
end fcs_check_serial;

architecture rtl of fcs_check_serial is

    signal crc_reg  : std_logic_vector(31 downto 0);
    signal next_crc  : std_logic_vector(31 downto 0);
    signal active   : std_logic;
    signal fcs_count: integer range 0 to 33;
    signal mac_count: integer range 0 to 33;
    signal proc_data: std_logic;
    signal complement: std_logic;
begin

    process(clk, reset)
    begin

        if reset = '1' then
            -- async reset
            crc_reg <= (others => '0');
            active <= '0';
            fcs_count <= 0;
            mac_count <= 0;
            fcs_error <= '0';
    
        elsif rising_edge(clk) then
            
            if start_of_frame = '1' then
                active <= '1';
            end if;    

            -- mac counter
            if start_of_frame = '1' and mac_count = 0 then
                mac_count <= 1;
            elsif mac_count >= 1 and mac_count < 31 then
                mac_count <= mac_count + 1;
            end if;

            if mac_count = 31 then
                mac_count <= 0;
            end if;    

            -- fcs counter
            if end_of_frame = '1' and fcs_count = 0 then
                fcs_count <= 1;
            elsif fcs_count >= 1 and fcs_count < 32 then
                fcs_count <= fcs_count + 1;
            end if;
            
            if fcs_count = 32 then
                active <= '0';
                fcs_count <= 0;
                if crc_reg = x"00000000" then
                    fcs_error <= '0';
                else
                    fcs_error <= '1';
                end if;
            end if; 
        
        -- CRC calculation (polynomial 0x04C11DB7)
            if (active = '1' or start_of_frame = '1') and fcs_count < 32 then
                crc_reg <= next_crc;
            end if;

        end if;

    end process;
    
    -- Combinational process
    complement  <= '1' when (mac_count >= 1 and mac_count <= 31) or (start_of_frame = '1' and mac_count = 0)
                         or (fcs_count >= 1 and fcs_count <= 31) or (end_of_frame = '1' and fcs_count = 0)
                  else '0';

    proc_data <= data_in xor complement;

    next_crc(0)  <= crc_reg(31) xor proc_data;
    next_crc(1)  <= crc_reg(0)  xor crc_reg(31);
    next_crc(2)  <= crc_reg(1)  xor crc_reg(31);
    next_crc(3)  <= crc_reg(2);
    next_crc(4)  <= crc_reg(3)  xor crc_reg(31);
    next_crc(5)  <= crc_reg(4)  xor crc_reg(31);
    next_crc(6)  <= crc_reg(5);
    next_crc(7)  <= crc_reg(6)  xor crc_reg(31);
    next_crc(8)  <= crc_reg(7)  xor crc_reg(31);
    next_crc(9)  <= crc_reg(8);
    next_crc(10) <= crc_reg(9)  xor crc_reg(31);
    next_crc(11) <= crc_reg(10) xor crc_reg(31);
    next_crc(12) <= crc_reg(11) xor crc_reg(31);
    next_crc(13) <= crc_reg(12);
    next_crc(14) <= crc_reg(13);
    next_crc(15) <= crc_reg(14);
    next_crc(16) <= crc_reg(15) xor crc_reg(31);
    next_crc(17) <= crc_reg(16);
    next_crc(18) <= crc_reg(17);
    next_crc(19) <= crc_reg(18);
    next_crc(20) <= crc_reg(19);
    next_crc(21) <= crc_reg(20);
    next_crc(22) <= crc_reg(21) xor crc_reg(31);
    next_crc(23) <= crc_reg(22) xor crc_reg(31);
    next_crc(24) <= crc_reg(23);
    next_crc(25) <= crc_reg(24);
    next_crc(26) <= crc_reg(25) xor crc_reg(31);
    next_crc(27) <= crc_reg(26);
    next_crc(28) <= crc_reg(27);
    next_crc(29) <= crc_reg(28);
    next_crc(30) <= crc_reg(29);
    next_crc(31) <= crc_reg(30);

end rtl;