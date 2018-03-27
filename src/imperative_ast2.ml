
open Parsetree
open Parsing_ast
open Clocking_ast
open Tools

type app_inits = imp_equation list
and init = imp_equation
and imp_inits = init list
and imp_expr =
  | IValue of value
  | IConstr of string
  | IVariable of ident
  | IArray of imp_expr list
  | IArray_get of imp_expr * imp_expr
  | IArray_fold of imp_expr * Parsetree.expression * imp_expr
  | IArray_map of imp_expr * Parsetree.expression
  | IImperative_update of imp_expr * ((imp_expr * imp_expr) list)
  | ICondact of bool * ident * imp_expr
  | IApplication of ident * int * imp_expr
  | IApplication_init of ident * imp_expr
  | ICall of Parsetree.expression
  | IRef of ident
  | IRefDef of imp_expr
  (* | IRefUpdate of ident * imp_expr *)
  | IInfixOp of imp_infop * imp_expr * imp_expr
  | IPrefixOp of imp_preop * imp_expr
  | IAlternative of imp_expr * imp_expr * imp_expr
  | IETuple of imp_expr list
  | IUnit
and
  imp_infop =
  | IEquals
  | IDiff
  | IPlus
  | IMinus
  | ITimes
  | IDiv
  | IPlusf
  | IMinusf
  | IDivf
  | ITimesf
  | IInf
  | IInfe
  | ISup
  | ISupe
  | IOr
  | IAnd
  | IMod

and
  imp_preop =
  | INot
  | INeg
  | INegf

and imp_equation =  {
  i_pattern : pattern;
  i_expression : imp_expr;
}

type imp_init = {
  i_init_init_apps : imp_equation list;
  i_init_equations : imp_equation list;
  i_init_init_fby : imp_equation list;
  i_init_init_pres : imp_equation list;
}

type imp_step = {
  i_step_equations : imp_equation list;
  i_step_updates : imp_equation list;
}

type imp_node = {
  i_name : pattern;
  i_inputs : pattern;
  i_outputs : pattern;
  i_init : imp_init;
  i_step : imp_step;
}



let rec print_pattern fmt p =
  match p.p_desc with
  | Ident i -> Format.fprintf fmt "%s" i
  | Tuple t -> print_list fmt print_pattern t
  | PUnit -> Format.fprintf fmt "()"
  | Typed (p,s) -> Format.fprintf fmt "(%a:%s)" print_pattern p s

  let rec printml_tuple fmt l =
    match l with
    | [] -> ()
    | [x] -> Format.fprintf fmt "%a"  print_pattern x
    | h::t -> Format.fprintf fmt "%a,"  print_pattern h; printml_tuple fmt t

let rec printml_expression fmt exp =
  let printml_preop fmt op =
    match op with
    | INot -> Format.fprintf fmt "not "
    | INeg -> Format.fprintf fmt "-"
    | INegf -> Format.fprintf fmt "-."
  in
  let printml_infop fmt op =
    match op with
    | IDiff -> Format.fprintf fmt "<>"
    | IEquals -> Format.fprintf fmt "="
    | IPlus -> Format.fprintf fmt "+"
    | ITimes -> Format.fprintf fmt "*"
    | IDiv -> Format.fprintf fmt "/"
    | IMinus -> Format.fprintf fmt "-"
    | IMinusf -> Format.fprintf fmt "-."
    | IDivf -> Format.fprintf fmt "/."
    | IPlusf -> Format.fprintf fmt "+."
    | ITimesf -> Format.fprintf fmt "*."
    | IInf -> Format.fprintf fmt "<"
    | IInfe -> Format.fprintf fmt "<="
    | ISup -> Format.fprintf fmt ">"
    | ISupe -> Format.fprintf fmt ">="
    | IOr -> Format.fprintf fmt "||"
    | IAnd -> Format.fprintf fmt "&&"
    | IMod -> Format.fprintf fmt "mod"
  in
  let rec printml_expressions fmt el =
    match el with
    | [] -> ()
    | e::[] -> Format.fprintf fmt "%a"
                 printml_expression e
    | e::tl -> Format.fprintf fmt "%a,%a"
                 printml_expression e
                 printml_expressions tl
  in
  match exp with
  | IValue c -> Parsing_ast_printer.print_value fmt c
  | IVariable v ->  Format.fprintf fmt "%s" v
  | IArray a -> Format.fprintf fmt "[| %a |]" printml_expressions a
  | IArray_get (e,e') -> Format.fprintf fmt "%a.(%a)" printml_expression e printml_expression e'
  | IArray_fold (e,f,e') -> Format.fprintf fmt "%a.fold(...,%a)" printml_expression e printml_expression e'
  | IArray_map (e,f) -> Format.fprintf fmt "%a.map(...)" printml_expression e
  | IImperative_update (e,el) -> Format.fprintf fmt "%a where (...)" printml_expression e
  | IRef v -> Format.fprintf fmt "!%s" v
  | IRefDef e -> Format.fprintf fmt "ref %a" printml_expression e
  | IInfixOp (op,e1,e2) -> Format.fprintf fmt "%a %a %a"
                             printml_expression e1
                             printml_infop op
                             printml_expression e2
  | IPrefixOp (op,e) -> Format.fprintf fmt "%a%a"
                          printml_preop op
                          printml_expression e
  | IAlternative (e1,e2,e3) -> Format.fprintf fmt "if %a then %a else %a"
                                 printml_expression e1
                                 printml_expression e2
                                 printml_expression e3
  | IUnit -> Format.fprintf fmt "()"
  | IApplication (i,num,e) -> Format.fprintf fmt "%s%d_app (%a)"
                              i
                              num
                             printml_expression e
  | IApplication_init (i,e) ->
     Format.fprintf fmt "%s (%a)"
                             i
                             printml_expression e
  | ICall e -> Format.fprintf fmt "(_____)"
  | IConstr s -> Format.fprintf fmt "%s" s
  | IETuple el -> Format.fprintf fmt "(%a)"
                    printml_expressions el
  | ICondact (b,i,e)  -> Format.fprintf fmt "if %s = %b then %a else nil" i b printml_expression e


let printml_updates fmt il =
  let aux fmt { i_pattern = s ; i_expression = e} =
    match e with
    | x -> Format.fprintf fmt "\t%a := %a;\n"
             print_pattern s
             printml_expression x
  in
  List.iter (aux fmt) il

let printml_equations fmt el =
  let printml_equation fmt e =
    Format.fprintf fmt "\tlet %a = %a in \n"
      print_pattern e.i_pattern
      printml_expression e.i_expression
  in
  List.iter (printml_equation fmt) el

let printml_init fmt init =
  let initapps = init.i_init_init_apps in
  let initfby = init.i_init_init_fby in
  let initpres = init.i_init_init_pres in
  let equations = init.i_init_equations in
  Format.fprintf fmt "%a%a%a%a"
    printml_equations initapps
    printml_equations equations
    printml_equations initfby
    printml_equations initpres


let printml_step fmt step =
  let equations = step.i_step_equations in
  let updates = step.i_step_updates in
  Format.fprintf fmt "%a%a"
    printml_equations equations
    printml_updates updates

let printml_inits fmt il =
  let printml_init fmt { i_pattern = s ; i_expression = e} =
    begin match e with
      | x -> Format.fprintf fmt "\tlet %a = %a in\n"
               print_pattern s
               printml_expression x
    end
  in
  List.iter (fun i -> printml_init fmt i) il

let printml_node fmt node =
  Format.fprintf fmt "\nlet %a %a =\n%a\t%a,fun %a -> \n %a\t%a\n"
    print_pattern node.i_name
    print_pattern node.i_inputs
    printml_init node.i_init
    print_pattern node.i_outputs
    print_pattern node.i_inputs
    printml_step node.i_step
    print_pattern node.i_outputs
