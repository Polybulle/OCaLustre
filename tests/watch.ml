module IO = struct
  let watch_inputs () =
    1

  let watch_outputs (h,m,s) =
    Printf.printf "%d:%d:%d\n" h m s;
    print_newline ();
    Unix.sleep 1
end

let%node count d ~return:(cpt) =
  cpt := (0 >>> cpt+1) mod d

let%node watch () ~return:(h,m,s) =
  seconds := count (60);
  seconds_ok := (seconds = 60);
  minute := count (60 [@ when seconds_ok]);
  s := seconds;
  m := minute;
  h := 3
  (* minutes_ok := (minute = 60); *)
  (* hour := count (12 [@ when minutes_ok]); *)
  (* s := seconds; *)
  (* m := merge seconds_ok minute 0; *)
  (* h := merge seconds_ok (merge minutes_ok hour 0) 0 *)