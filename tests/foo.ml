

let%node test ~i:(x) ~o:(z) =
  pre (x >= 0); post (z >= x); inv (z = x+y && y >=0);
  y = 0 ->> (y + 1);
  z = x + y
