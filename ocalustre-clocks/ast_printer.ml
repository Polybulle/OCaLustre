open Ast

let print_value fmt v =
  match v with
  | Integer i -> Format.fprintf fmt "%d" i

let rec print_list f fmt l =
  match l with
  | [s] -> Format.fprintf fmt  "%a" f s
  | h :: t -> Format.fprintf fmt  "%a, " f h ; print_list f fmt t
  | _ -> ()

let print_ident fmt i = Format.fprintf fmt "%s" i.content

let print_io fmt l =
  let print_one fmt x =
    Format.fprintf fmt "%s"
      x.content
  in
  Format.fprintf fmt "(%a)"
    (print_list (fun fmt io -> print_one fmt io)) l

let rec print_tuple fmt l =
  match l with
  | [x] -> Format.fprintf fmt "%s" x.content
  | h::t -> Format.fprintf fmt "%s," h.content; print_tuple fmt t
  | [] -> ()

let print_pattern fmt p =
  Format.fprintf fmt "(%s)"
    p.content

let print_preop fmt op =
  match op with
  | Not -> Format.fprintf fmt "not "


let print_infop fmt op =
  match op with
  | Equals -> Format.fprintf fmt "="
  | Plus -> Format.fprintf fmt "+"
  | Times -> Format.fprintf fmt "*"
  | Div -> Format.fprintf fmt "/"
  | Minus -> Format.fprintf fmt "-"
  | Diff -> Format.fprintf fmt "<>"
  | Plusf -> Format.fprintf fmt "+."
  | Timesf -> Format.fprintf fmt "*."
  | Divf -> Format.fprintf fmt "/."
  | Minusf -> Format.fprintf fmt "-."


let rec print_expression fmt e =
  let rec print_expression_list fmt el =
    match el with
    | [] -> ()
    | [e] -> Format.fprintf fmt "%a" print_expression e
    | he::te -> Format.fprintf fmt "%a,%a" print_expression he print_expression_list te
  in
  match e with
  | Variable i -> Format.fprintf fmt "%a"
                    print_ident i
  | Alternative (e1,e2,e3) ->
    Format.fprintf fmt  "(if (%a) then (%a) else (%a))"
      print_expression e1
      print_expression e2
      print_expression e3
  | Application (i, el) ->
     Format.fprintf fmt "(%a (%a))"
                    print_ident i
                    print_expression_list el
  | InfixOp (op, e1, e2) ->
    Format.fprintf fmt "(%a %a %a)"
      print_expression e1
      print_infop op
      print_expression e2
  | PrefixOp (op, e1) -> Format.fprintf fmt "(%a %a)"
                           print_preop op
                           print_expression e1

  | Value v -> print_value fmt v
  | Fby (v, e) -> Format.fprintf fmt "(%a fby %a)"
                    print_value v
                    print_expression e
  | Arrow (v,e) -> Format.fprintf fmt "(%a --> %a)"
                     print_value v
                     print_expression e
  | Unit -> Format.fprintf fmt "()"
  | When (e,i) -> Format.fprintf fmt "( %a when %a )"
                    print_expression e
                    print_ident i
  | Current e -> Format.fprintf fmt "( current %a)"
                   print_expression e
  | Pre e -> Format.fprintf fmt "(pre %a)"
               print_expression e


let print_equation fmt e =
  Format.fprintf fmt  "  %a = %a;"
    print_pattern e.pattern
    print_expression e.expression

let rec print_equations fmt le =
  match le with
  | [] -> ()
  | e::[] -> Format.fprintf fmt "%a"
               print_equation e
  | e::tl -> Format.fprintf fmt "%a \n%a"
               print_equation e
               print_equations tl

let print_node fmt n =
  Format.fprintf fmt  "let_node %s ~inf:%a ~outf:%a = \n%a \n \n"
    n.name.content
    print_io n.inputs
    print_io n.outputs
    print_equations n.equations
