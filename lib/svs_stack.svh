`ifndef __SVS_STACK_SVH__
`define __SVS_STACK_SVH__

`include "svs_frame.svh"
`include "svs_node.svh"
`include "svs_logger.svh"

class svs_stack;

  svs_frame stack[$];
  svs_node vars[string];
  svs_node funcs[string];

  function new();
    stack = {};
  endfunction

  function push_frame(svs_frame f);
    svs_frame nf = new;
    if(top())
      nf.copy(top());
    nf.copy(f);
    stack.push_back(nf);
  endfunction

  function pop_frame();
    stack.pop_back();
  endfunction

  function svs_frame top();
    integer depth = stack.size();
    if(depth == 0)
      return null;
    else
      return stack[$];
  endfunction

  function add_param(string n, svs_node v);
    svs_frame st = top();
    if(st != null)
      st.add_param(n, v);
    else
      `SVS_ERROR("cannot add parameter in global scope")
  endfunction

  function add_var(string n, svs_node v);
    vars[n] = v;
  endfunction

  function add_func(string n, svs_node v);
    funcs[n] = v;
  endfunction

  function svs_node read_param(string n);
    svs_frame st = top();
    if(st != null && st.param_exists(n))
      return st.read_param(n);
    else
      `SVS_ERROR({"cannot find parameter ", n})
  endfunction

  function int param_exists(string n);
    svs_frame st = top();
    if(st != null && st.param_exists(n))
      return 1;
    else
      return 0;
  endfunction

  function svs_node read_var(string n);
    if(vars.exists(n))
      return vars[n]; 
    else
      `SVS_ERROR({"cannot find variable ", n})
  endfunction

  function int var_exists(string n);
    return vars.exists(n);
  endfunction

  function svs_node read_func(string n);
    if(funcs.exists(n))
      return funcs[n];
    else
      `SVS_ERROR({"cannot find function ", n})
  endfunction

  function int func_exists(string n);
    return funcs.exists(n);
  endfunction

endclass

`endif
