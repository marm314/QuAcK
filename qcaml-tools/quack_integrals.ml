let quack_dir =
  try Sys.getenv "QUACK_ROOT" with
  Not_found -> "."

module Command_line = Qcaml.Common.Command_line
module Util = Qcaml.Common.Util

let () =
  let open Command_line in
  begin
    set_header_doc (Sys.argv.(0) ^ " - QuAcK command");
    set_description_doc "Computes the one- and two-electron integrals on the Gaussian atomic basis set.";
    set_specs
      [ { short='b' ; long="basis" ; opt=Mandatory;
          arg=With_arg "<string>";
          doc="Name of the file containing the basis set"; } ;

        { short='x' ; long="xyz" ; opt=Mandatory;
          arg=With_arg "<string>";
          doc="Name of the file containing the nuclear coordinates in xyz format"; } ;

        { short='u' ; long="range-separation" ; opt=Optional;
          arg=With_arg "<float>";
          doc="Range-separation parameter."; } ;
      ]
  end;

  let basis_file  = Util.of_some @@ Command_line.get "basis" in
  let nuclei_file = Util.of_some @@ Command_line.get "xyz" in
  let range_separation = 
    match Command_line.get "range-separation" with
    | None -> None
    | Some mu -> Some (float_of_string mu) 
  in

  let nuclei =
    Qcaml.Particles.Nuclei.of_xyz_file nuclei_file
  in

  let operators = 
    match range_separation with
    | None -> []
    | Some mu -> [ Qcaml.Operators.Operator.of_range_separation mu ]
  in

  let ao_basis =
    Qcaml.Ao.Basis.of_nuclei_and_basis_filename ~kind:`Gaussian
      ~operators ~cartesian:true ~nuclei basis_file
  in

  let overlap   = Qcaml.Ao.Basis.overlap   ao_basis in
  let eN_ints   = Qcaml.Ao.Basis.eN_ints   ao_basis in
  let kin_ints  = Qcaml.Ao.Basis.kin_ints  ao_basis in
  let ee_ints   = Qcaml.Ao.Basis.ee_ints   ao_basis in
  let multipole = Qcaml.Ao.Basis.multipole ao_basis in
  let x_mat = Qcaml.Gaussian_integrals.Multipole.matrix_x multipole in
  let y_mat = Qcaml.Gaussian_integrals.Multipole.matrix_y multipole in
  let z_mat = Qcaml.Gaussian_integrals.Multipole.matrix_z multipole in

  Qcaml.Gaussian_integrals.Overlap.to_file ~filename:(quack_dir ^ "/int/Ov.dat") overlap;
  Qcaml.Gaussian_integrals.Electron_nucleus.to_file ~filename:(quack_dir ^ "/int/Nuc.dat") eN_ints;
  Qcaml.Gaussian_integrals.Kinetic.to_file ~filename:(quack_dir ^ "/int/Kin.dat") kin_ints;
  Qcaml.Gaussian_integrals.Eri.to_file    ~filename:(quack_dir ^ "/int/ERI.dat") ee_ints;
  Qcaml.Gaussian_integrals.Multipole.to_file ~filename:(quack_dir ^ "/int/x.dat") x_mat;
  Qcaml.Gaussian_integrals.Multipole.to_file ~filename:(quack_dir ^ "/int/y.dat") y_mat;
  Qcaml.Gaussian_integrals.Multipole.to_file ~filename:(quack_dir ^ "/int/z.dat") z_mat;

  match range_separation with
  | Some _mu ->
      Qcaml.Gaussian_integrals.Eri_long_range.to_file ~filename:(quack_dir ^ "/int/ERI_lr.dat") (Qcaml.Ao.Basis.ee_lr_ints ao_basis)
  | None -> ()



