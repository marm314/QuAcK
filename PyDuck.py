#!/usr/bin/env python3

import os
import sys
import argparse
import pyscf
from pyscf import gto
from pyscf.tools import molden
import numpy as np
import subprocess
import time
import gc
try:
    import pyopencap
    use_cap = True
except ImportError:
    print("Module pyopencap is not installed.")
    use_cap = False

# Find the value of the environnement variable QUACK_ROOT. If not present we use the current repository
if "QUACK_ROOT" not in os.environ:
    print("Please set the QUACK_ROOT environment variable, for example:\n")
    print("$ export QUACK_ROOT={0}".format(os.getcwd()))
    sys.exit(1)
QuAcK_dir = os.environ.get('QUACK_ROOT', './')

# Create the argument parser object and gives a description of the script
parser = argparse.ArgumentParser(
    description='This script is the main script of QuAcK, it is used to run the calculation.\n If $QUACK_ROOT is not set, $QUACK_ROOT is replaces by the current directory.')

# Initialize all the options for the script
parser.add_argument('-b', '--basis', type=str, required=True,
                    help='Name of the file containing the basis set information in the $QUACK_ROOT/basis/ directory')
parser.add_argument('--bohr', default='Angstrom', action='store_const', const='Bohr',
                    help='By default QuAcK assumes that the xyz files are in Angstrom. Add this argument if your xyz file is in Bohr.')
parser.add_argument('-c', '--charge', type=int, default=0,
                    help='Total charge of the molecule. Specify negative charges with "m" instead of the minus sign, for example m1 instead of -1. Default is 0')
parser.add_argument('--cartesian', default=False, action='store_true',
                    help='Add this option if you want to use cartesian basis functions.')
parser.add_argument('--print_2e', default=True,
                    action='store_true', help='If True, print ERIs to disk.')
parser.add_argument('--formatted_2e', default=False, action='store_true',
                    help='Add this option if you want to print formatted ERIs.')
parser.add_argument('--mmap_2e', default=False, action='store_true',
                    help='If True, avoid using DRAM when generating ERIs.')
parser.add_argument('--aosym_2e', default=False, action='store_true',
                    help='If True, use 8-fold symmetry in ERIs.')
parser.add_argument('-fc', '--frozen_core', type=bool,
                    default=False, help='Freeze core orbitals. Default is false')
parser.add_argument('-m', '--multiplicity', type=int, default=1,
                    help='Spin multiplicity. Default is 1 (singlet)')
parser.add_argument('--working_dir', type=str, default=QuAcK_dir,
                    help='Set a working directory to run the calculation.')
parser.add_argument('-x', '--xyz', type=str, required=True,
                    help='Name of the file containing the nuclear coordinates in xyz format in the $QUACK_ROOT/mol/ directory without the .xyz extension')

parser.add_argument('-dm', '--dump_molden', default=False, action='store_true',
                    help='Dump molden file with the dyson orbitals. Make sure that in the Quack Code before compilation the keyword writeMOs in cRHF or complex_qsRGW is set to true. So far, this is only available for cRHF and complex_qsRGW.')

# Parse the arguments
args = parser.parse_args()
working_dir = args.working_dir
input_basis = args.basis
unit = args.bohr
charge = args.charge
frozen_core = args.frozen_core
multiplicity = args.multiplicity
xyz = args.xyz + '.xyz'
cartesian = args.cartesian
print_2e = args.print_2e
formatted_2e = args.formatted_2e
mmap_2e = args.mmap_2e
aosym_2e = args.aosym_2e
dump_molden = args.dump_molden
# Read molecule
f = open(working_dir+'/mol/'+xyz, 'r')
lines = f.read().splitlines()
nbAt = int(lines.pop(0))
lines.pop(0)
list_pos_atom = []
for line in lines:
    tmp = line.split()
    atom = tmp[0]
    pos = (float(tmp[1]), float(tmp[2]), float(tmp[3]))
    list_pos_atom.append([atom, pos])
f.close()
# Create PySCF molecule
if use_cap:
    atoms = list(set(atom[0] for atom in list_pos_atom))
    if os.path.exists(input_basis):
        basis_dict = {atom: gto.basis.parse_nwchem.load(
            input_basis, atom) for atom in atoms}
    else:
        basis_dict = {atom: gto.basis.parse_nwchem.load(
            working_dir + "/basis/" + input_basis, atom) for atom in atoms}
    basis = basis_dict
    mol = gto.M(
        atom=list_pos_atom,
        basis=basis,
        charge=charge,
        spin=multiplicity - 1
        #    symmetry = True  # Enable symmetry
    )
else:
    mol = gto.M(
        atom=list_pos_atom,
        basis=input_basis,
        charge=charge,
        spin=multiplicity - 1
        #    symmetry = True  # Enable symmetry
    )
# Fix the unit for the lengths
mol.unit = unit
#
mol.cart = cartesian

# Update mol object
mol.build()

# Accessing number of electrons
nelec = mol.nelec  # Access the number of electrons
nalpha = nelec[0]
nbeta = nelec[1]

subprocess.call(['mkdir', '-p', working_dir+'/input'])
f = open(working_dir+'/input/molecule', 'w')
f.write('# nAt nEla nElb nCore nRyd\n')
f.write(str(mol.natm)+' '+str(nalpha)+' ' +
        str(nbeta)+' '+str(0)+' '+str(0)+'\n')
f.write('# Znuc x  y  z\n')
for i in range(len(list_pos_atom)):
    f.write(list_pos_atom[i][0]+' '+str(list_pos_atom[i][1][0])+' ' +
            str(list_pos_atom[i][1][1])+' '+str(list_pos_atom[i][1][2])+'\n')
f.close()

# Compute nuclear energy and put it in a file
subprocess.call(['mkdir', '-p', working_dir+'/int'])
subprocess.call(['rm', '-f', working_dir + '/int/ENuc.dat'])
f = open(working_dir+'/int/ENuc.dat', 'w')
f.write(str(mol.energy_nuc()))
f.write(' ')
f.close()

# Compute 1e integrals
ovlp = mol.intor('int1e_ovlp')  # Overlap matrix elements
v1e = mol.intor('int1e_nuc')  # Nuclear repulsion matrix elements
t1e = mol.intor('int1e_kin')  # Kinetic energy matrix elements
dipole = mol.intor('int1e_r')  # Matrix elements of the x, y, z operators
x, y, z = dipole[0], dipole[1], dipole[2]

norb = len(ovlp)  # nBAS_AOs
subprocess.call(['rm', '-f', working_dir + '/int/nBas.dat'])
f = open(working_dir+'/int/nBas.dat', 'w')
f.write(" {} ".format(str(norb)))
f.close()


def create_psi4_basis(basis_dict):
    """
    Converts a dictionary representation of a basis set (pyscf internal format) into a Psi4-formatted string.

    Parameters:
        basis_dict (dict): A dictionary where keys are element symbols and values are lists of primitives.
                           Each primitive is represented as [angular momentum, [exponent, coefficient(s)]].

    Returns:
        str: filepath to the create file containing the psi4 formatted basis
    """
    l_mapping = {0: 'S', 1: 'P', 2: 'D', 3: 'F', 4: 'G', 5: 'H'}
    basis_str = "****\n"
    for element, shells in basis_dict.items():
        basis_str += f"{element}     0\n"

        for shell in shells:
            l_value = shell[0]
            l_letter = l_mapping.get(l_value, str(l_value))
            primitives = shell[1:]
            num_primitives = len(primitives)

            # Determine number of contractions
            max_contractions = max(len(p) - 1 for p in primitives)

            for contraction_idx in range(max_contractions):
                basis_str += f"{l_letter}   {num_primitives}   1.00\n"
                for primitive in primitives:
                    exponent = primitive[0]
                    coefficient = primitive[1 + contraction_idx] if len(
                        primitive) > (1 + contraction_idx) else 0.0
                    basis_str += f"     {exponent: .6E} {coefficient: .6E}\n"
        basis_str += "****\n"
    basis_filename_psi4 = working_dir + "/input/basis_psi4"
    with open(basis_filename_psi4, "w") as file:
        file.write(basis_str.strip())
    return basis_filename_psi4


# CAP definition
if use_cap:
    try:
        f = open(working_dir+'/cap_data/'+args.xyz, 'r')
        lines = f.read().splitlines()
        line = lines[1]
        tmp = line.split()
        onset_x = float(tmp[0])
        onset_y = float(tmp[1])
        onset_z = float(tmp[2])
        eta_opt = float(tmp[3])
        f.close()
        f = open(working_dir+'/input/eta_opt.dat', 'w')
        f.write(" {} ".format(str(eta_opt)))
        f.close()
        print(f"CAP eta = {eta_opt}")

        # xyz file
        with open(working_dir + "/mol/" + xyz, "r") as f:
            lines = f.readlines()
            f.close()
        num_atoms = int(lines[0].strip())
        atoms = [line.strip() for line in lines[2:2+num_atoms]]
        if unit == 'Bohr':
            bohr_coordinates = 'true'
        else:
            bohr_coordinates = 'false'
        sys_dict = {
            "molecule": "inline",
            "geometry": "\n".join(atoms),  # XYZ format as a string
            "basis_file": create_psi4_basis(basis_dict),
            "bohr_coordinates": bohr_coordinates
        }
        cap_system = pyopencap.System(sys_dict)
        if not(cap_system.check_overlap_mat(ovlp, "pyscf")):
            raise Exception(
                "Provided cap basis does not match to the pyscf basis.")
        cap_dict = {"cap_type": "box",
                    "cap_x": onset_x,
                    "cap_y": onset_y,
                    "cap_z": onset_z,
                    "Radial_precision": "16",
                    "angular_points": "590",
                    "thresh": 15}
        pc = pyopencap.CAP(cap_system, cap_dict, norb)
        cap_ao = pc.get_ao_cap(ordering="pyscf")
    except Exception:
        print("No CAP-data provided for this molecule. Skipping CAP calculation...")
        use_cap = False


def write_matrix_to_file(matrix, size, file, cutoff=1e-15):
    f = open(file, 'w')
    for i in range(size):
        for j in range(i, size):
            if abs(matrix[i][j]) > cutoff:
                f.write(str(i+1)+' '+str(j+1)+' ' +
                        "{:.16E}".format(matrix[i][j]))
                f.write('\n')
    f.close()


# Write all 1 electron quantities in files
# Ov,Nuc,Kin,x,y,z,CAP
subprocess.call(['rm', '-f', working_dir + '/int/Ov.dat'])
write_matrix_to_file(ovlp, norb, working_dir+'/int/Ov.dat')
subprocess.call(['rm', '-f', working_dir + '/int/Nuc.dat'])
write_matrix_to_file(v1e, norb, working_dir+'/int/Nuc.dat')
subprocess.call(['rm', '-f', working_dir + '/int/Kin.dat'])
write_matrix_to_file(t1e, norb, working_dir+'/int/Kin.dat')
subprocess.call(['rm', '-f', working_dir + '/int/x.dat'])
write_matrix_to_file(x, norb, working_dir+'/int/x.dat')
subprocess.call(['rm', '-f', working_dir + '/int/y.dat'])
write_matrix_to_file(y, norb, working_dir+'/int/y.dat')
subprocess.call(['rm', '-f', working_dir + '/int/z.dat'])
write_matrix_to_file(z, norb, working_dir+'/int/z.dat')
if use_cap:
    subprocess.call(['rm', '-f', working_dir + '/int/CAP.dat'])
    write_matrix_to_file(cap_ao, norb, working_dir+'/int/CAP.dat')


def write_tensor_to_file(tensor, size, file_name, cutoff=1e-15):
    f = open(file_name, 'w')
    for i in range(size):
        for j in range(i, size):
            for k in range(i, size):
                for l in range(j, size):
                    if abs(tensor[i][k][j][l]) > cutoff:
                        f.write(str(i+1)+' '+str(j+1)+' '+str(k+1)+' ' +
                                str(l+1)+' '+"{:.16E}".format(tensor[i][k][j][l]))
                        f.write('\n')
    f.close()


if print_2e:
    # Write two-electron integrals to HD
    ti_2e = time.time()

    if formatted_2e:
        output_file_path = working_dir + '/int/ERI.dat'
        subprocess.call(['rm', '-f', output_file_path])
        eri_ao = mol.intor('int2e')
        write_tensor_to_file(eri_ao, norb, output_file_path)

    if aosym_2e:
        output_file_path = working_dir + '/int/ERI_chem.bin'
        subprocess.call(['rm', '-f', output_file_path])
        eri_ao = mol.intor('int2e', aosym='s8')
        f = open(output_file_path, 'w')
        eri_ao.tofile(output_file_path)
        f.close()
    else:
        output_file_path = working_dir + '/int/ERI.bin'
        subprocess.call(['rm', '-f', output_file_path])
        if(mmap_2e):
            # avoid using DRAM
            eri_shape = (norb, norb, norb, norb)
            eri_mmap = np.memmap(
                output_file_path, dtype='float64', mode='w+', shape=eri_shape)
            mol.intor('int2e', out=eri_mmap)
            for i in range(norb):
                eri_mmap[i, :, :, :] = eri_mmap[i, :, :, :].transpose(1, 0, 2)
            eri_mmap.flush()
            del eri_mmap
        else:
            eri_ao = mol.intor('int2e').transpose(0, 2, 1, 3)  # chem -> phys
            f = open(output_file_path, 'w')
            eri_ao.tofile(output_file_path)
            f.close()

    te_2e = time.time()
    print(
        "Wall time for writing 2e-integrals to disk: {:.3f} seconds".format(te_2e - ti_2e))
    sys.stdout.flush()

# Free memory
del ovlp, v1e, t1e, x, y, z
if print_2e and not(mmap_2e):
    del eri_ao
if use_cap:
    del cap_ao, pc
gc.collect()

# Execute the QuAcK fortran program
subprocess.call([QuAcK_dir + '/bin/QuAcK', working_dir])

if dump_molden:
    real_mo_coeff = np.loadtxt('real_MOs.dat')
    imag_mo_coeff = np.loadtxt('imag_MOs.dat')
    subprocess.call(['rm','real_MOs.dat'])
    subprocess.call(['rm','imag_MOs.dat'])
    molden.from_mo(mol, "real_MOs.molden", real_mo_coeff)
    molden.from_mo(mol, "imag_MOs.molden", imag_mo_coeff)
