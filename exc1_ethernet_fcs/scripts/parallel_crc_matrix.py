import numpy as np

N = 32
POLY_TAPS = [0, 1, 2, 4, 5, 7, 8, 10, 11, 12, 16, 22, 23, 26]

A = np.zeros((N, N), dtype=int)

for bit in range(N):
    if bit > 0:
        A[bit][bit-1] = 1  
        if bit in POLY_TAPS:
            A[bit][31] = 1 # XOR with MSB if it's a tap
    else:
        # Row 0: no shift, just gets the MSB feedback
        A[0][31] = 1

def matmul_gf2(M1, M2):
    return np.dot(M1, M2) % 2

def matpow_gf2(M, p):
    res = np.eye(len(M), dtype=int)
    for _ in range(p):
        res = matmul_gf2(res, M)
    return res

A8 = matpow_gf2(A, 8)

#input data matrix
b = np.zeros(N, dtype=int)
b[0] = 1 

def matvec_gf2(M, v):
    return np.dot(M, v) % 2

M_data = np.zeros((N, 8), dtype=int)

for j in range(8):
    # data_in[j] is injected at cycle (7-j). 
    # By cycle 8, it has been multiplied by A^j
    M_data[:, j] = matvec_gf2(matpow_gf2(A, j), b)

def print_matrix(A_mat, M_mat):
    print("      0 1 2 3 4 5 6 7 8 9 10111213141516171819202122232425262728293031  d0d1d2d3d4d5d6d7")
    print("  " + "-"*87)
    for i in range(N):
        # Format Register matrix (A_mat)
        a_str = " ".join(["1" if x else "." for x in A_mat[i]])
        # Format Data matrix (M_mat)
        m_str = "".join(["1" if x else "." for x in M_mat[i]])
        print(f" {i:2d} | {a_str}  {m_str}")

print("=== Matrix A (Step 1) ===")
print_matrix(A, M_data) # Note: M_data here isn't cycle 1 M_data, just printing for format

print("\n=== Matrix A^8 and M_data (Step 8) ===")
print_matrix(A8, M_data)