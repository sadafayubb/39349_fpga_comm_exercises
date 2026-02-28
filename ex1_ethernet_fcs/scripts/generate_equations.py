def generate_parallel_crc():
    # 32 strings representing the current crc register
    crc_reg = [{f"crc_reg({i})"} for i in range(32)]

    # array of 8 strings for data
    data_in = [{f"data_in({i})"} for i in range(8)]

    # generator polynomial to apply taps
    poly_taps = [0, 1, 2, 4, 5, 7, 8, 10, 11, 12, 16, 22, 23, 26]

    for i in range(8):
        # for xor we use ^  (symmetric difference)
        new_crc_reg = [None]*32

        new_crc_reg[0] = crc_reg[31] ^ data_in[7-i]

        for bit in range(1, 32): # from 1 to 31
            if bit in poly_taps:
                # if there is tap, xor with previous bit with r31
                new_crc_reg[bit] = crc_reg[bit-1] ^ crc_reg[31]
            else:
                # if no tap, just shift
                new_crc_reg[bit] = crc_reg[bit-1]
        
        crc_reg = new_crc_reg  

    # build output lines
    lines = []  

    for i in range(32):
        # Sort data_in terms first, then crc_reg terms, both numerically
        terms = sorted(
            list(crc_reg[i]),
            key=lambda x: (0 if x.startswith("data") else 1, int(x.split("(")[1].rstrip(")")))
        )
        expr = " xor ".join(terms) if terms else "'0'"
        lines.append(f"next_crc_reg({i:2d}) <= {expr};")
    
    return lines

if __name__ == "__main__":
    lines = generate_parallel_crc() 

    for line in lines:
        print(line)

    # save to file
    with open("parallel_crc_equations.txt", "w") as f:
        f.write("\n".join(lines))

    print("\nSaved to parallel_crc_equations.txt")   

