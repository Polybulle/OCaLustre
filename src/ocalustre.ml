open Ast_mapper
open Ast_helper
open Asttypes
open Parsetree
open Longident
open Parsing_ocl
open Parsing_ast
open Parsing_ast_printer
open Scheduler
open Normalizing
open Sequential_ast
open Sequential_ast_printer
open Proof_printer
open Sequentialize
open Codegen
open Error
(* open Compiling *)
open Imperative_ast

let verbose = ref false
let clocking = ref false
let lustre = ref false
let no_auto = ref false
let why = ref false
let nonalloc = ref false
let typing = ref false
let not_printed_wrapper = ref true
let main = ref ""
let outputs_env = ref []


let env = ref []
let mini_env = ref []
(* let env2 = ref [] *)
(* maps structure_items of the form :

   let%node NAME (IN1,IN2,...) ~return:(OUT1, OUT2, ...) =
    OUT1 := EQ1;
    ...
    OUTX := EQX
*)

let to_lustre_file node =
  let name = !Location.input_name in
  let name = Filename.remove_extension name in
  let name = name^".ls" in
  let oc = open_out_gen [ Open_wronly; Open_creat ; Open_append] 0o640 name in
  let fmt =  Format.formatter_of_out_channel oc in
  Format.fprintf fmt "%a" Lustre_printer.print_node  node;
  close_out oc;
  Format.printf "File %s has been written for node %s. \n" name (string_of_pattern node.name)

let create_node mapper str =
  match str.pstr_desc with
  | Pstr_extension (({txt="node";_},PStr [s]),_) ->
    begin match s.pstr_desc with
      | Pstr_value (_,[v]) ->
        let _node = mk_node v.pvb_pat v.pvb_expr in
        let _norm_node = if !no_auto then _node else normalize_node _node in
        let _sched_node = if !no_auto then _node else schedule _norm_node in

          begin
            if !verbose then
              Format.fprintf Format.std_formatter "Before Scheduling : \n %a \nAfter Scheduling : \n %a"
              print_node _sched_node
              print_node _sched_node;
            if !lustre then to_lustre_file _node;
            (* if !why then ( *)
              (* let whyml = Proof_compiling.pcompile_cnode _sched_node in *)
            (* whyml_node Format.std_formatter whyml); *)
            (* Format.printf "ENV = %a\n" Clocks.print_env !env; *)
            (* let (_new_env2,_cnode2) = Clocking2.clock_node !env2 _sched_node in *)
            (* failwith "ok"; *)
            let (new_env,_cnode) = Clocking.clock_node !env _sched_node in
            env := new_env;
            (* env2 := _new_env2; *)
            if !clocking then(
              Clocking_ast_printer.print_node Format.std_formatter (_cnode,!verbose);
            );
            mini_env := Miniclock.clock_node !mini_env _sched_node;
            let _icnode = Compiling_w_clocks.compile_cnode _cnode in
            if !verbose then Imperative_ast2.printml_node Format.std_formatter _icnode;
            if not !nonalloc then
              begin
                (* let _inode = compile_cnode _sched_node in *)
                (* if !verbose then Imperative_ast_printer.printml_node Format.std_formatter _inode; *)
                let stri = if !main = string_of_pattern _icnode.i_name then
                    [Extracting2.tocaml_main _icnode]
                  else
                    []
                in
                let str = Extracting2.tocaml_node _icnode::stri in
                (* let str = Extracting.tocaml_node _inode::stri in *)
                (* if !typing then *)
                  (* Print_type.print_type str; *)
                str
              end
            else
              let _seq_node = seq_node _sched_node outputs_env in
              if !verbose then print_s_node Format.std_formatter _seq_node;
              let str = tocaml_node _seq_node in
              if !typing then
                Print_type.print_type str;
              str
          end
      | _ -> Error.syntax_error s.pstr_loc "not a node"
    end
  | x -> [default_mapper.structure_item mapper str]


(* maps structure (i.e list of structure_items) *)
let lustre_mapper argv =
  { default_mapper with
    structure =
      fun mapper st ->
        let stl = List.map (create_node mapper) st in
        List.flatten stl
  }

open Compiling_w_clocks
let _ =
  let speclist = [("-v", Arg.Set verbose, "Enables verbose mode");
                  ("-y", Arg.Set why, "Prints whyml code");
                  ("-n", Arg.Set no_auto, "Don't normalize, don't schedule");
                  ("-l", Arg.Set lustre, "Prints lustre node");
                  ("-a", Arg.Set nonalloc, "Generate non-allocating code (state passing style)");
                  ("-m", Arg.Set_string main, "Generate main function");
                  ("-i", Arg.Set clocking, "Prints node clocks");
                  ("-t", Arg.Set typing, "Prints node types");]
  in let usage_msg = "OCaLustre : "
  in Arg.parse speclist print_endline usage_msg;
  register "ocalustre" lustre_mapper
