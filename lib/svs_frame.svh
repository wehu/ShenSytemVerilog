`ifndef __SVS_FRAME_SVH__
`define __SVS_FRAME_SVH__

`include "svs_node.svh"
`include "svs_logger.svh"

class svs_frame;

  svs_node params[string];

  function new();
  endfunction

  function add_param(string n, svs_node v);
    params[n] = v;
  endfunction

  function int param_exists(string n);
    return params.exists(n);
  endfunction

  function svs_node read_param(string n);
    if(params.exists(n))
      return params[n];
    else
      `SVS_ERROR({"unknown parameter ", n})
  endfunction

  function copy(svs_frame o);
    string i;
    foreach(o.params[i])
      this.params[i] = o.params[i];
  endfunction

endclass

`endif
