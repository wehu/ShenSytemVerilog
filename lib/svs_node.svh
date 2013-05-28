`ifndef __SVS_NODE_SVH__
`define __SVS_NODE_SVH__

`include "svs_logger.svh"

typedef class svs_frame;

typedef struct svs_node_t;
typedef class svs_node;

typedef struct {
  string as_string;
  real as_number;
  svs_node as_seq[$];
} svs_node_t;


class svs_node;

  string typ;
  svs_node_t val;
  string filename;
  integer line;
  integer col;

  bit dot;

  svs_frame scope;

  function new(string t="symbol", svs_node_t v='{"", 0, {}});
    typ = t;
    val = v;
    filename = "unknown";
    line = 0;
    col  = 0;
  endfunction

  function error(string msg="");
    string nmsg;
    $sformat(nmsg, "%s [file: %s; line: %d; col: %d]", msg, filename, line, col);
    `SVS_ERROR(nmsg)
  endfunction

  function string to_string();
    string s;
    if(typ == "number") begin
      s.realtoa(val.as_number);
    end else if(typ == "string") begin
      s = val.as_string;
    end else if(typ == "list" || typ == "function" || typ == "tc" || typ == "absvector" || typ == "cons") begin
      integer i;
      s = "(";
      for(i=0; i< val.as_seq.size(); i++) begin
        s = {s, val.as_seq[i].to_string(), " "};
        if(dot == 1 && i == val.as_seq.size()-2)
          s = {s, ". "};
      end
      s = {s, ")"};
    end else begin
      s = val.as_string;
    end
    return s;
  endfunction

  function void show();
    $display(to_string());
  endfunction

endclass

`endif
