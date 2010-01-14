exception Failure of string
val file_of_url : ?dest:string -> string -> string
(** [file_of_url ?dest  url] Downloads a given document and returns
the place where it is stored. Default [dest] is in [/tmp]. *)
