`ifndef __SVS_EVALER_SVH__
`define __SVS_EVALER_SVH__

`include "svs_node.svh"
`include "svs_stack.svh"
`include "svs_reader.svh"

`define TC_READY 0
`define TC_ON_CHAIN 1
`define TC_RESET 2

class svs_evaler;

  svs_stack stack;

  static svs_node empty_list = new("list", '{"", 0, {}, {}});
  static svs_node true = new("bool", '{"true", 0, {}, {}});
  static svs_node false = new("bool", '{"false", 0, {}, {}});
  static svs_node nil = new("symbol", '{"NIL", 0, {}, {}});
  int primitives[string];
  static integer object_counter = 0;

  bit enable_tco;

  svs_node exception;

  function new();
    string ps[] = '{"if",
                     "and",
                     "or",
                     "cond",
                     "intern",
                     "pos",
                     "tlstr",
                     "cn",
                     "str",
                     "string?",
                     "n->string",
                     "string->n",
                     "set",
                     "value",
                     "simple-error",
                     "trap-error",
                     "error-to-string",
                     "cons",
                     "hd",
                     "tl",
                     "cons?",
                     "defun",
                     "lambda",
                     "let",
                     "=",
                     "eval-kl",
                     "freeze",
                     "type",
                     "absvector",
                     "address->",
                     "<-address",
                     "absvector?",
                     "pr",
                     "read-byte",
                     "open",
                     "close",
                     "get-time",
                     "+",
                     "-",
                     "*",
                     "/",
                     ">",
                     "<",
                     ">=",
                     "<=",
                     "number?",
                     "display",
                     "do",
                     "exit"};
    integer i;
    svs_reader reader;
    for(i=0; i<=ps.size(); i++) begin
      primitives[ps[i]] = 1;
    end
    reader = new;
    stack = new;
    enable_tco = 1;
    exception = null;
  endfunction

  //function svs_node error(svs_node ast, string msg);
  //  return new_exception(ast, msg);
  //endfunction

  function svs_node load_file(string file);
    svs_reader reader = new;
    svs_node ast = reader.read_file(file);
    return eval_file(ast); 
  endfunction

  function svs_node eval_file(svs_node ast);
    integer i;
    integer l = ast.val.as_seq.size();
    svs_node res;
    for(i=0; i<l; i++) begin
      res = eval(ast.val.as_seq[i], `TC_READY);
      if(exception != null) begin
        $display(exception.val.as_string);
        $finish();
      end
    end
    return res;
  endfunction

  function svs_node new_node(svs_node ast, string typ);
    svs_node n = new(typ);
    n.filename = ast.filename;
    n.line = ast.line;
    n.col = ast.col;
    return n;
  endfunction

  function svs_node eval(svs_node ast, int tc=`TC_RESET);
    string typ = ast.typ;
    string str = ast.val.as_string;
    svs_node res;
    if(typ == "list") begin
      if(ast.val.as_seq.size() == 0)
        return empty_list;
      else begin
        res = eval_application(ast, tc);
        if(exception != null)
          return exception;
        while(res.typ == "tc") begin
          if(tc == `TC_ON_CHAIN)
            return res;
          res = eval_tc(res);
          if(exception != null)
            return exception;
        end
        return res;
      end
    end else if(typ == "symbol" &&
                (str == "true" ||
                 str == "false" ||
                 str == "NIL")) begin
       if(str == "true")
         return true;
       else if(str == "false")
         return false;
       else if(str == "NIL")
         return nil;
    end else if(param_exists(ast)) begin
      if(exception != null)
        return exception;
      res = bind_param(ast);
      if(exception != null)
        return exception;
      return res;
    end else begin
      //return bind_var(ast);
      return ast;
    end
  endfunction

  function svs_node new_exception(svs_node ast, string msg);
    string nmsg;
    $sformat(nmsg, "%s [file: %s; line: %d; col: %d]", msg, ast.filename, ast.line, ast.col);
    exception = new_node(ast, "exception");
    exception.val.as_string = nmsg;
    return exception;
  endfunction

  function svs_node eval_application(svs_node ast, int tc);
    svs_node f;
    string ftyp;
    string fn;
    integer size;
    svs_node res;
    f = ast.val.as_seq[0];
    ftyp = f.typ;
    fn = f.val.as_string;
    if(ftyp == "symbol" && fn != "trap-error" && exception != null)
      return exception;
    f = eval(ast.val.as_seq[0]);
    ftyp = f.typ;
    fn = f.val.as_string;
    size = ast.val.as_seq.size();
    if(exception != null)
      return exception;
    if(ftyp == "symbol") begin
      f = bind_func(f);
      if(exception != null)
        return exception;
    end
    ftyp = f.typ;
    if(ftyp != "function" && ftyp != "symbol")
      return new_exception(ast, {"expect a function or symbol but got ", ftyp});
//$display(fn);
    if(fn != "trap-error" && exception != null)
      return exception;
    if(fn == "exit")
      $finish();
    else if(fn == "if")
      res = eval_if(ast, tc);
    else if(fn == "and")
      res = eval_and(ast);
    else if(fn == "or")
      res = eval_or(ast);
    else if(fn == "cond")
      res = eval_cond(ast, tc);
    else if(fn == "intern")
      res = eval_intern(ast);
    else if(fn == "pos")
      res = eval_pos(ast);
    else if(fn == "tlstr")
      res = eval_tlstr(ast);
    else if(fn == "cn")
      res = eval_cn(ast);
    else if(fn == "str")
      res = eval_str(ast);
    else if(fn == "string?")
      res = eval_string_p(ast);
    else if(fn == "n->string")
      res = eval_n_to_string(ast);
    else if(fn == "string->n")
      res = eval_string_to_n(ast);
    else if(fn == "set")
      res = eval_set(ast);
    else if(fn == "value")
      res = eval_value(ast);
    else if(fn == "simple-error")
      res = eval_simple_error(ast);
    else if(fn == "trap-error")
      res = eval_trap_error(ast);
    else if(fn == "error-to-string")
      res = eval_error_to_string(ast);
    else if(fn == "cons")
      res = eval_cons(ast);
    else if(fn == "hd")
      res = eval_hd(ast);
    else if(fn == "tl")
      res = eval_tl(ast);
    else if(fn == "cons?")
      res = eval_cons_p(ast);
    else if(fn == "defun" || fn == "lambda" || fn == "freeze")
      res = eval_func(ast);
    else if(fn == "let")
      res = eval_let(ast, tc);
    else if(fn == "=")
      res = eval_equal(ast);
    else if(fn == "eval-kl")
      res = eval_eval_kl(ast);
    else if(fn == "type")
      res = eval_type(ast);
    else if(fn == "absvector")
      res = eval_absvector(ast);
    else if(fn == "address->")
      res = eval_address_w(ast);
    else if(fn == "<-address")
      res = eval_address_r(ast);
    else if(fn == "absvector?")
      res = eval_absvector_p(ast);
    else if(fn == "pr")
      res = eval_pr(ast);
    else if(fn == "read-byte")
      res = eval_read_byte(ast);
    else if(fn == "open")
      res = eval_open(ast);
    else if(fn == "close")
      res = eval_close(ast);
    else if(fn == "get-time")
      res = eval_get_time(ast);
    else if(fn == "+" ||
            fn == "-" ||
            fn == "*" ||
            fn == "/" ||
            fn == ">" ||
            fn == "<" ||
            fn == ">=" ||
            fn == "<=")
      res = eval_arithmetic(ast);
    else if(fn == "number?")
      res = eval_number_p(ast);
    else if(fn == "do")
      res = eval_do(ast, tc);
    else if(fn == "display")
      res = eval_display(ast);
    else begin
      integer i;
      svs_node rargs[$];
      svs_frame scope = new;
      svs_node fargs = f.val.as_seq[0];
      integer fsize = f.val.as_seq.size();
      scope.copy(f.scope);
      if(fargs.val.as_seq.size() > size-1)
        return partial(ast, size);
      if(fargs.val.as_seq.size() != size-1)
        return new_exception(ast, "the size of real arguments does not match the formal arguments");
      for(i=1; i<size; i++) begin
        svs_node l = eval(ast.val.as_seq[i]);
        if(exception != null)
          return exception;
        rargs.push_back(l);
      end
      stack.push_frame(scope);
      for(i=0; i<size-1; i++) begin
        stack.add_param(fargs.val.as_seq[i].val.as_string, rargs[i]);
      end
      //for(i=1; i<fsize; i++) begin
        if(f.val.as_seq[1].typ == "list" && tc != `TC_RESET && enable_tco == 1)
          res = tco(f.val.as_seq[1]);
        else
          res = eval(f.val.as_seq[1], `TC_READY);
        stack.pop_frame();
        if(exception != null)
          return exception;
      //end
    end
    if(exception != null)
      return exception;
    return res;
  endfunction

  function svs_node tco(svs_node ast);
    string typ = ast.typ;
    svs_node tc;
    svs_frame f;
    if(typ != "list")
      return new_exception(ast, {"expects a list for tco but got ", typ});
    tc = new_node(ast, "tc");
    tc.val = ast.val;
    f = new;
    if(stack.top() != null)
      f.copy(stack.top());
    tc.scope = f;
    return tc; 
  endfunction

  function svs_node eval_tc(svs_node tc);
    string typ = tc.typ;
    svs_node app;
    svs_node res;
    svs_frame f;
    if(typ != "tc")
      return new_exception(tc, {"expects a tc for evalution but got ", typ});
    app = new_node(tc, "list");
    app.val = tc.val;
    f = new;
    f.copy(tc.scope);
    stack.push_frame(f);
    res = eval(app, `TC_ON_CHAIN);
    stack.pop_frame();
    if(exception != null)
      return exception;
    return res; 
  endfunction

  function string gen_name();
    string n;
    $sformat(n, "___ %d", object_counter);
    object_counter ++;
    return n;
  endfunction

  function svs_node partial(svs_node ast, integer rsize);
    integer size = ast.val.as_seq.size();
    svs_node p = new_node(ast, "function");
    svs_frame f = new();
    svs_node fargs = new_node(ast, "list");
    svs_node body = new_node(ast, "list");
    integer i;
    if(stack.top() != null)
      f.copy(stack.top());
    body.val.as_seq.push_back(ast.val.as_seq[0]);
    for(i=1; i<size; i++) begin
      svs_node a = eval(ast.val.as_seq[i]);
      string n = gen_name();
      svs_node nn = new_node(ast, "symbol");
      if(exception != null)
        return exception;
      f.add_param(n, a);
      nn.val.as_string = n;
      body.val.as_seq.push_back(nn);
    end
    for(; i<rsize; i++) begin
      string n = gen_name();
      svs_node nn = new_node(ast, "symbol");
      nn.val.as_string = n;
      fargs.val.as_seq.push_back(nn);
      body.val.as_seq.push_back(nn);
    end
    p.val.as_seq.push_back(fargs);
    p.val.as_seq.push_back(body);
    p.scope = f;
    return p;
  endfunction

  function svs_node eval_if(svs_node ast, int tc);
    integer size = ast.val.as_seq.size();
    svs_node c;
    svs_node l;
    svs_node r;
    svs_node res;
    if(size != 3 && size != 4)
      return new_exception(ast, "if expects 2 or 3 arguments");
    c = eval(ast.val.as_seq[1]);
    if(exception != null)
      return exception;
    if(c.typ != "bool")
      return new_exception(ast, {"if expects a boolean as the first argument but got ", c.typ});
    if(c == true) begin
      if(ast.val.as_seq[2].typ == "list" && tc != `TC_RESET && enable_tco == 1)
        res = tco(ast.val.as_seq[2]);
      else
        res = eval(ast.val.as_seq[2], `TC_READY);
      if(exception != null)
        return exception;
    end else begin
      if(size == 4) begin
        if(ast.val.as_seq[3].typ == "list" && tc != `TC_RESET && enable_tco == 1)
          res = tco(ast.val.as_seq[3]);
        else
          res = eval(ast.val.as_seq[3], `TC_READY);
        if(exception != null)
          return exception;
      end else
        res = nil; 
    end
    return res;
  endfunction

  function svs_node eval_and(svs_node ast);
    integer size = ast.val.as_seq.size();
    svs_node res;
    integer i;
    if(size < 3)
      return partial(ast, 3);
    for(i=1; i<size; i++) begin
      res = eval(ast.val.as_seq[i]);
      if(exception != null)
        return exception;
      if(res.typ != "bool")
        return new_exception(ast, {"and expects boolean as arguments but got ", res.typ});
      if(res == false)
        return false;
    end
    return res;
  endfunction

  function svs_node eval_or(svs_node ast);
    integer size = ast.val.as_seq.size();
    svs_node res;
    integer i;
    if(size < 3)
      return partial(ast, 3);
    for(i=1; i<size; i++) begin
      res = eval(ast.val.as_seq[i]);
      if(exception != null)
        return exception;
      if(res.typ != "bool")
        return new_exception(ast, {"or expects boolean as arguments but got ", res.typ});
      if(res == true)
        return true;
    end
    return res;
  endfunction

  function svs_node eval_cond(svs_node ast, int tc);
    integer size = ast.val.as_seq.size();
    svs_node res;
    integer i;
    svs_node p;
    integer psize;
    if(size < 2)
      return new_exception(ast, "cond expects >= 1 arguments");
    for(i=1; i<size; i++) begin
      svs_node c;
      p = ast.val.as_seq[i];
      if(p.typ != "list")
        return new_exception(ast, {"cond expects pair as arguments but got ", p.typ});
      psize = p.val.as_seq.size();
      if(psize != 2)
        return new_exception(ast, "cond expects pair as arguments");
      c = eval(p.val.as_seq[0]);
      if(exception != null)
        return exception;
      if(c.typ != "bool")
        return new_exception(ast, {"cond's pair expects a boolean as the first argument but got ", c.typ});
      if(c == true) begin
        if(p.val.as_seq[1].typ == "list" && tc != `TC_RESET && enable_tco == 1)
          res = tco(p.val.as_seq[1]);
        else 
          res = eval(p.val.as_seq[1], `TC_READY);
        if(exception != null)
          return exception;
        return res;
      end
    end
    return nil;
  endfunction

  function svs_node eval_pos(svs_node ast);
    integer size = ast.val.as_seq.size();
    svs_node s;
    svs_node i;
    svs_node res;
    if(size < 3)
      return partial(ast, 3);
    if(size != 3)
      return new_exception(ast, "pos expects 2 arguments");
    s = eval(ast.val.as_seq[1]);
    if(exception != null)
      return exception;
    if(s.typ != "string")
      return new_exception(ast, {"pos expects a string as the first argument but got ", s.typ});
    i = eval(ast.val.as_seq[2]);
    if(exception != null)
      return exception;
    if(i.typ != "number")
      return new_exception(ast, {"pos expects a number as the second argument but got ", i.typ});
    res = new_node(ast, "string");
    res.val.as_string = string'(s.val.as_string[integer'(i.val.as_number)]);
    return res;
  endfunction

  function svs_node eval_tlstr(svs_node ast);
    integer size = ast.val.as_seq.size();
    svs_node s;
    svs_node res;
    if(size < 2)
      return partial(ast, 2);
    if(size != 2)
      return new_exception(ast, "tlstr expects 1 argument");
    s = eval(ast.val.as_seq[1]);
    if(exception != null)
      return exception;
    if(s.typ != "string")
      return new_exception(ast, {"tlstr expects a string as the first argument but got ", s.typ});
    res = new_node(ast, "string");
    res.val.as_string = s.val.as_string.substr(1, s.val.as_string.len()-1);
    return res;
  endfunction

  function svs_node eval_cn(svs_node ast);
    integer size = ast.val.as_seq.size();
    svs_node l;
    svs_node r;
    svs_node res;
    if(size < 3)
      return partial(ast, 3);
    if(size != 3)
      return new_exception(ast, "cn expects 2 argument");
    l = eval(ast.val.as_seq[1]);
    if(exception != null)
      return exception;
    if(l.typ != "string")
      return new_exception(ast, {"cn expects a string as the first argument but got ", l.typ});
    r = eval(ast.val.as_seq[2]);
    if(exception != null)
      return exception;
    if(r.typ != "string")
      return new_exception(ast, {"cn expects a string as the first argument but got ", r.typ});
    res = new_node(ast, "string");
    res.val.as_string = {l.val.as_string, r.val.as_string};
    return res;
  endfunction

  function svs_node eval_str(svs_node ast);
    integer size = ast.val.as_seq.size();
    svs_node s;
    svs_node res;
    if(size < 2)
      return partial(ast, 2);
    if(size != 2)
      return new_exception(ast, "str expects 1 argument");
    s = eval(ast.val.as_seq[1]);
    if(exception != null)
      return exception;
    //if(s.typ != "string" && s.typ != "symbol" && s.typ != "bool" && s.typ != "number")
    //  return new_exception(ast, {"cn expects an atom as the first argument but got ", s.typ});
    res = new_node(ast, "string");
    if(s.typ == "number") begin
      string n;
      n.realtoa(s.val.as_number);
      res.val.as_string = n; //{"^", n, "^"};
    end else if(s.typ == "string" || s.typ == "symbol" || s.typ == "bool")
      res.val.as_string = s.val.as_string; //{"^", s.val.as_string, "^"};
    else
      res.val.as_string = "...";
    return res;
  endfunction

  function svs_node eval_string_p(svs_node ast);
    integer size = ast.val.as_seq.size();
    svs_node s;
    if(size < 2)
      return partial(ast, 2);
    if(size != 2)
      return new_exception(ast, "string? expects 1 argument");
    s = eval(ast.val.as_seq[1]);
    if(exception != null)
      return exception;
    if(s.typ == "string")
      return true;
    else
      return false;
  endfunction

  function svs_node eval_n_to_string(svs_node ast);
    integer size = ast.val.as_seq.size();
    svs_node n;
    svs_node res;
    if(size < 2)
      return partial(ast, 2);
    if(size != 2)
      return new_exception(ast, "n->string expects 1 argument");
    n = eval(ast.val.as_seq[1]);
    if(exception != null)
      return exception;
    if(n.typ != "number")
      return new_exception(ast, {"n->string expects a number as the first argument but got ", n.typ});
    if(n.val.as_number < 0 || n.val.as_number > 255)
      return new_exception(ast, "n->string expects a number > 0 and < 256");
    res = new_node(ast, "string");
    res.val.as_string = string'(integer'(n.val.as_number));
    return res;
  endfunction

  function svs_node eval_string_to_n(svs_node ast);
    integer size = ast.val.as_seq.size();
    svs_node s;
    svs_node res;
    if(size < 2)
      return partial(ast, 2);
    if(size != 2)
      return new_exception(ast, "string->n expects 1 argument");
    s = eval(ast.val.as_seq[1]);
    if(exception != null)
      return exception;
    if(s.typ != "string" || s.val.as_string.len() != 1)
      return new_exception(ast, {"string->n expects a char as the first argument but got ", s.typ});
    res = new_node(ast, "number");
    res.val.as_number = integer'(s.val.as_string);
    return res;
  endfunction

  function svs_node eval_intern(svs_node ast);
    integer size = ast.val.as_seq.size();
    svs_node s;
    svs_node res;
    if(size < 2)
      return partial(ast, 2);
    if(size != 2)
      return new_exception(ast, "intern expects 1 argument");
    s = eval(ast.val.as_seq[1]);
    if(exception != null)
      return exception;
    if(s.typ != "string")
      return new_exception(ast, {"intern expects a symbol as the argument but got ", s.typ});
    res = new_node(ast, "symbol");
    res.val.as_string = s.val.as_string;
    return res;
  endfunction

  function svs_node eval_set(svs_node ast);
    integer size = ast.val.as_seq.size();
    svs_node n;
    svs_node v;
    if(size < 3)
      return partial(ast, 3);
    if(size != 3)
      return new_exception(ast, "set expects 2 arguments");
    n = eval(ast.val.as_seq[1]);
    if(exception != null)
      return exception;
    if(n.typ != "symbol")
      return new_exception(ast, {"set expects a symbol as the first argument but got ", n.typ});
    //stack.add_var(n.val.as_string, nil);
    v = eval(ast.val.as_seq[2]);
    if(exception != null)
      return exception;
    stack.add_var(n.val.as_string, v);
    return v;
  endfunction

  function svs_node eval_value(svs_node ast);
    integer size = ast.val.as_seq.size();
    svs_node n;
    svs_node res;
    if(size < 2)
      return partial(ast, 2);
    if(size != 2)
      return new_exception(ast, "value expects 1 argument");
    n = eval(ast.val.as_seq[1]);
    if(exception != null)
      return exception;
    if(n.typ != "symbol")
      return new_exception(ast, {"value expects a symbol as the argument but got", n.typ});
    res = bind_var(n);
    return res;
  endfunction

  function svs_node eval_simple_error(svs_node ast);
    integer size = ast.val.as_seq.size();
    svs_node msg;
    svs_node e;
    if(size < 2)
      return partial(ast, 2);
    if(size != 2)
      return new_exception(ast, "simple-error expects 1 argument");
    msg = eval(ast.val.as_seq[1]);
    if(exception != null)
      return exception;
    if(msg.typ != "string")
      return new_exception(ast, {"simple-error expects a string as the argument but got", msg.typ});
    e = new_node(ast, "exception");
    e.val.as_string = msg.val.as_string;
    exception = e;
    return e;
  endfunction

  function svs_node eval_trap_error(svs_node ast);
    integer size = ast.val.as_seq.size();
    svs_node cb;
    svs_node res;
    svs_node e;
    if(size < 3)
      return partial(ast, 3);
    if(size != 3)
      return new_exception(ast, "trap-error expects 2 arguments");
    res = eval(ast.val.as_seq[1]);
    e = exception;
    exception = null;
    cb = eval(ast.val.as_seq[2]);
    if(exception != null)
      return exception;
    if(cb.typ != "function")
      return new_exception(ast, {"trap-error expects a function as the second argument but got", cb.typ});
    if(e != null) begin
      svs_node fc = new_node(ast, "list");
      fc.val.as_seq.push_back(cb);
      fc.val.as_seq.push_back(e);
      res = eval(fc);
      if(exception != null)
        return exception;
    end
    return res;
  endfunction

  function svs_node eval_error_to_string(svs_node ast);
    integer size = ast.val.as_seq.size();
    svs_node e;
    svs_node res;
    if(size < 2)
      return partial(ast, 2);
    if(size != 2)
      return new_exception(ast, "error-to-string expects 1 argument");
    e = eval(ast.val.as_seq[1]);
    if(exception != null)
      return exception;
    if(e.typ != "exception")
      return new_exception(ast, {"error-to-string expects an exception as the argument but got ", e.typ});
    res = new_node(ast, "string");
    res.val.as_string = e.val.as_string;
    return res;
  endfunction

  function svs_node eval_cons(svs_node ast);
    integer size = ast.val.as_seq.size();
    svs_node i;
    svs_node l;
    svs_node res;
    if(size < 3)
      return partial(ast, 3);
    if(size != 3)
      return new_exception(ast, "cons expects 2 arguments");
    i = eval(ast.val.as_seq[1]);
    if(exception != null)
      return exception;
    l = eval(ast.val.as_seq[2]);
    if(exception != null)
      return exception;
    res = new_node(ast, "cons");
    res.val.as_seq.push_back(i);
    res.val.as_seq.push_back(l);
    return res;
  endfunction

  function svs_node eval_hd(svs_node ast);
    integer size = ast.val.as_seq.size();
    svs_node l;
    svs_node res;
    if(size < 2)
      return partial(ast, 2);
    if(size != 2)
      return new_exception(ast, "hd expects 1 argument");
    l = eval(ast.val.as_seq[1]);
    if(exception != null)
      return exception;
    if(l.typ != "cons")
      return new_exception(ast, {"hd expects a list as the second argument but got ", l.typ});
    res = l.val.as_seq[0];
    return res;
  endfunction

  function svs_node eval_tl(svs_node ast);
    integer size = ast.val.as_seq.size();
    svs_node l;
    svs_node res;
    if(size < 2)
      return partial(ast, 2);
    if(size != 2)
      return new_exception(ast, "tl expects 1 argument");
    l = eval(ast.val.as_seq[1]);
    if(exception != null)
      return exception;
    if(l.typ != "cons")
      return new_exception(ast, {"tl expects a list as the second argument but got ", l.typ});
    res = l.val.as_seq[1];
    return res;
  endfunction

  function svs_node eval_cons_p(svs_node ast);
    integer size = ast.val.as_seq.size();
    svs_node l;
    if(size < 2)
      return partial(ast, 2);
    if(size != 2)
      return new_exception(ast, "cons? expects 1 argument");
    l = eval(ast.val.as_seq[1]);
    if(exception != null)
      return exception;
    if(l.typ == "cons")
      return true;
    else
      return false;
  endfunction

  function svs_node eval_display(svs_node ast);
    integer size = ast.val.as_seq.size();
    svs_node res;
    if(size < 2)
      return partial(ast, 2);
    if(size != 2)
      return new_exception(ast, "display expects 1 argument");
    res = eval(ast.val.as_seq[1]);
    if(exception != null)
      return exception;
    res.show();
    return res;
  endfunction

  function svs_node eval_func(svs_node ast);
    string fn = ast.val.as_seq[0].val.as_string;
    integer fsize = ast.val.as_seq.size();
    svs_node f = new_node(ast, "function");
    svs_node fargs;
    string defn;
    svs_frame scope = new;
    integer i;
    integer fargs_size;
    if(fn == "defun") begin
      svs_node n;
      string ntype;
      if(fsize < 4)
        return partial(ast, 4);
      if(fsize != 4)
       return new_exception(ast, "defun expects 3 arguments");
      n = eval(ast.val.as_seq[1]);
      if(exception != null)
        return exception;
      ntype = n.typ;
      if(ntype != "symbol")
        return new_exception(ast, {"defun expect a symbol as function name but got ", ntype});
      defn = ast.val.as_seq[1].val.as_string;
      fargs = ast.val.as_seq[2];
    end else if(fn == "lambda") begin
      if(fsize < 3)
        return partial(ast, 3);
      if(fsize != 3)
       return new_exception(ast, "lambda expects 2 arguments");
      fargs = new_node(ast, "list");
      fargs.val.as_seq.push_back(ast.val.as_seq[1]);
    end else begin
      if(fsize < 2)
        return partial(ast, 2);
      if(fsize != 2)
       return new_exception(ast, "freeze expects 1 argument");
      fargs = new_node(ast, "list");
    end
    if(fargs.typ != "list")
      return new_exception(ast, {"defun or lambda expects a list as function formal arguments but got ", fargs.typ});
    fargs_size = fargs.val.as_seq.size();
    for(i=0; i<fargs_size; i++) begin
      if(fargs.val.as_seq[i].typ != "symbol")
        return new_exception(ast, {"defun or lambda expects a symbol as function formal argument but got ", fargs.val.as_seq[i].typ});
    end
    f.val.as_seq.push_back(fargs);
    if(fn == "defun")
      i = 3;
    else if(fn == "lambda")
      i = 2;
    else
      i = 1;
    f.val.as_seq.push_back(ast.val.as_seq[i]);
    if(fn == "defun")
      stack.add_func(defn, f);
    if(stack.top() != null)
      scope.copy(stack.top());
    f.scope = scope;
    return f;
  endfunction

  function svs_node eval_let(svs_node ast, int tc);
    integer size = ast.val.as_seq.size();
    svs_node n;
    svs_node v;
    svs_node res;
    svs_frame f;
    if(size != 4)
      return new_exception(ast, "let expects 3 arguments");
    n = ast.val.as_seq[1];
    if(n.typ != "symbol")
      return new_exception(ast, {"let expects a symbol as the first argument but got ", n.typ});
    v = eval(ast.val.as_seq[2]);
    if(exception != null)
      return exception;
    f = new;
    if(stack.top() != null)
      f.copy(stack.top());
    stack.push_frame(f);
    stack.add_param(n.val.as_string, v);
    if(ast.val.as_seq[3].typ == "list" && tc != `TC_RESET && enable_tco == 1)
      res = tco(ast.val.as_seq[3]);
    else
      res = eval(ast.val.as_seq[3], `TC_READY);
    stack.pop_frame();
    if(exception != null)
      return exception;
    return res;
  endfunction

  function svs_node eval_equal(svs_node ast, integer d=0);
    integer size = ast.val.as_seq.size();
    svs_node l;
    svs_node r;
    svs_node res;
    if(size < 3)
      return partial(ast, 3);
    if(size != 3)
      return new_exception(ast, "= expects 2 arguments");
    if(d == 0)
      l = eval(ast.val.as_seq[1]);
    else
      l = ast.val.as_seq[1];
    if(exception != null)
      return exception;
    if(d == 0)
      r = eval(ast.val.as_seq[2]);
    else
      r = ast.val.as_seq[2];
    if(exception != null)
      return exception;
    if(r.typ != l.typ)
      return false;
    else if(l.typ == "string" || l.typ == "symbol") begin
      if(l.val.as_string == r.val.as_string)
        return true;
    end else if(l.typ == "number") begin
      if(l.val.as_number == r.val.as_number)
        return true;
    end else if(l.typ == "absvector" || l.typ == "cons") begin
      integer ll;
      integer rl;
      integer i;
      if(l.typ == "absvector") begin
        ll = l.val.as_array.size();
        rl = r.val.as_array.size();
      end else begin
        ll = l.val.as_seq.size();
        rl = r.val.as_seq.size();
      end
      if(ll != rl)
        return false;
      for(i=0; i<ll; i++) begin
        svs_node e = new_node(ast, "list");
        svs_node ef = new_node(ast, "symbol");
        svs_node er;
        ef.val.as_string = "=";
        e.val.as_seq.push_back(ef);
        if(l.typ == "absvector") begin
          e.val.as_seq.push_back(l.val.as_array[i]);
          e.val.as_seq.push_back(l.val.as_array[i]);
        end else begin
          e.val.as_seq.push_back(l.val.as_seq[i]);
          e.val.as_seq.push_back(r.val.as_seq[i]);
        end
        er = eval_equal(e, d+1);
        if(exception != null)
          return exception;
        if(er == false)
          return false;
      end
      return true;
    end else if(l == r) begin
      return true;
    end
    return false;
  endfunction

  function svs_node eval_eval_kl(svs_node ast);
    integer size = ast.val.as_seq.size();
    svs_node res;
    if(size < 2)
      return partial(ast, 2);
    if(size != 2)
      return new_exception(ast, "eval-kl expects 1 argument");
    res = eval(ast.val.as_seq[1]);
    if(exception != null)
      return exception;
    if(res.typ == "cons") begin
      res = eval(translate_ast(res));
      if(exception != null)
        return exception;
    end
    return res;
  endfunction

  function svs_node translate_ast(svs_node ast);
    integer size = ast.val.as_seq.size();
    svs_node res;
    if(ast.typ == "cons") begin
      svs_node t = ast;
      res = new("list");
      while(t.typ == "cons") begin
        res.val.as_seq.push_back(translate_ast(t.val.as_seq[0]));
        t = t.val.as_seq[1];
      end
    end else begin
      res = ast;
    end
    return res;
  endfunction

  function svs_node eval_type(svs_node ast);
    return nil;
  endfunction

  function svs_node eval_absvector(svs_node ast);
    integer size = ast.val.as_seq.size();
    svs_node res = new_node(ast, "absvector");
    svs_node i;
    //svs_node n0 = new_node(ast, "number");
    integer vi;
    //n0.val.as_number = 0;
    if(size < 2)
      return partial(ast, 2);
    if(size != 2)
      return new_exception(ast, "absvector expects 1 argument");
    i = eval(ast.val.as_seq[1]);
    if(exception != null)
      return exception;
    if(i.typ != "number")
      return new_exception(ast, {"absvector expects a number as the first argument but got ", i.typ});
    if(i.val.as_number == 0)
      return new_exception(ast, "absvector size should > 0");
    //n0.val.as_number = i.val.as_number;
    //res.val.as_seq.push_back(n0);
    res.val.as_array = new[integer'(i.val.as_number)];
    //for(vi=0; vi<i.val.as_number; vi++) begin
    //  res.val.as_array[vi] = nil;
    //end
    return res;
  endfunction

  function svs_node eval_address_w(svs_node ast);
    integer size = ast.val.as_seq.size();
    svs_node vec;
    svs_node i;
    svs_node v;
    if(size < 4)
      return partial(ast, 4);
    if(size != 4)
      return new_exception(ast, "address-> expects 3 arguments");
    vec = eval(ast.val.as_seq[1]);
    if(exception != null)
      return exception;
    if(vec.typ != "absvector")
      return new_exception(ast, {"address-> expects an absvector as the first argument but got ", vec.typ});
    i = eval(ast.val.as_seq[2]);
    if(exception != null)
      return exception;
    if(i.typ != "number")
      return new_exception(ast, {"address-> expects an number as the second argument but got ", i.typ});
    if(i.val.as_number >= vec.val.as_array.size())
      return new_exception(ast, "address-> index > size"); 
    v = eval(ast.val.as_seq[3]);
    if(exception != null)
      return exception;
    vec.val.as_array[integer'(i.val.as_number)] = v;
    return vec;
  endfunction

  function svs_node eval_address_r(svs_node ast);
    integer size = ast.val.as_seq.size();
    svs_node vec;
    svs_node i;
    svs_node v;
    if(size < 3)
      return partial(ast, 3);
    if(size != 3)
      return new_exception(ast, "<-address expects 2 arguments");
    vec = eval(ast.val.as_seq[1]);
    if(exception != null)
      return exception;
    if(vec.typ != "absvector")
      return new_exception(ast, {"<-address expects an absvector as the first argument but got ", vec.typ});
    i = eval(ast.val.as_seq[2]);
    if(exception != null)
      return exception;
    if(i.typ != "number")
      return new_exception(ast, {"<-address expects an number as the second argument but got ", i.typ});
    if(i.val.as_number >= vec.val.as_array.size())
      return new_exception(ast, "<-address index > size ");
    v = vec.val.as_array[integer'(i.val.as_number)];
    return v;
  endfunction

  function svs_node eval_absvector_p(svs_node ast);
    integer size = ast.val.as_seq.size();
    svs_node vec;
    if(size < 2)
      return partial(ast, 2);
    if(size != 2)
      return new_exception(ast, "absvector? expects 1 argument");
    vec = eval(ast.val.as_seq[1]);
    if(exception != null)
      return exception;
    if(vec.typ == "absvector")
      return true;
    else
      return false;
  endfunction

  function svs_node eval_pr(svs_node ast);
    integer size = ast.val.as_seq.size();
    svs_node s;
    svs_node str;
    integer sid;
    if(size < 3)
      return partial(ast, 3);
    if(size != 3)
      return new_exception(ast, "pr expects 2 arguments");
    str = eval(ast.val.as_seq[1]);
    if(exception != null)
      return exception;
    if(str.typ != "string")
      return new_exception(ast, {"pr expects a string as the first argument but got ", str.typ});
    s = eval(ast.val.as_seq[2]);
    if(exception != null)
      return exception;
    if(s.typ != "stream-out" && s.typ != "number")
      return new_exception(ast, {"pr expects a stream-out or number as the first argument but got ", s.typ});
    sid = integer'(s.val.as_number);
    $fwrite(sid, str.val.as_string);
    return str;
  endfunction

  function svs_node eval_read_byte(svs_node ast);
    integer size = ast.val.as_seq.size();
    svs_node s;
    svs_node res;
    integer c;
    integer sid;
    if(size < 2)
      return partial(ast, 2);
    if(size != 2)
      return new_exception(ast, "read-byte expects 1 argument");
    s = eval(ast.val.as_seq[1]);
    if(exception != null)
      return exception;
    if(s.typ != "stream-in" && s.typ != "number")
      return new_exception(ast, {"read-byte expects a stream-in or number as the first argument but got ", s.typ});
    sid = integer'(s.val.as_number);
    c = $fgetc(sid);
    res = new_node(ast, "number");
    res.val.as_number = c;
    return res;
  endfunction

  function svs_node eval_open(svs_node ast);
    integer size = ast.val.as_seq.size();
    svs_node s;
    string file;
    svs_node a1;
    svs_node a2;
    svs_node a3;
    integer sid;
    if(size < 4)
      return partial(ast, 4);
    if(size != 4)
      return new_exception(ast, "open expects 3 arguments");
    a1 = eval(ast.val.as_seq[1]);
    if(exception != null)
      return exception;
    if(a1.typ != "symbol" || a1.val.as_string != "file")
      return new_exception(ast, {"open expects a symbol file as the first argument but got ", a1.typ});
    a2 = eval(ast.val.as_seq[2]);
    if(exception != null)
      return exception;
    if(a2.typ != "string")
      return new_exception(ast, {"open expects a string as the second argument but got ", a2.typ});
    a3 = eval(ast.val.as_seq[3]);
    if(exception != null)
      return exception;
    if(a3.typ != "symbol" || (a3.val.as_string != "in" && a3.val.as_string != "out"))
      return new_exception(ast, {"open expects a symbol in or out as the third argument but got ", a3.typ});
    if(a3.val.as_string == "in") begin
      sid = $fopen(a2.val.as_string, "r");
      s = new_node(ast, "stream-in");
    end else begin
      sid = $fopen(a2.val.as_string, "w");
      s = new_node(ast, "stream-out");
    end
    if(sid == 0) begin
      return new_exception(ast, {"cannot open file ", a2.val.as_string});
    end
    s.val.as_number = real'(sid);
    return s;
  endfunction

  function svs_node eval_close(svs_node ast);
    integer size = ast.val.as_seq.size();
    svs_node s;
    svs_node res;
    integer sid;
    if(size < 2)
      return partial(ast, 2);
    if(size != 2)
      return new_exception(ast, "close expects 1 argument");
    s = eval(ast.val.as_seq[1]);
    if(exception != null)
      return exception;
    if(s.typ != "stream-in" && s.typ != "stream-out")
      return new_exception(ast, {"close expects a stream as the first argument but got ", s.typ});
    sid = integer'(s.val.as_number);
    $fclose(sid);
    res = empty_list;
    return res;
  endfunction

  function svs_node eval_get_time(svs_node ast);
    integer size = ast.val.as_seq.size();
    svs_node mod;
    svs_node res;
    real t;
    if(size != 2)
      return new_exception(ast, "get-time expects 1 arguments");
    mod = eval(ast.val.as_seq[1]);
    if(exception != null)
      return exception;
    if(mod.typ != "symbol" || (mod.val.as_string != "run" && mod.val.as_string != "real"))
      return new_exception(ast, {"get-time expects a symbol run or real as the first argument but got ", mod.typ});
    t = $realtime();
    res = new_node(ast, "number");
    res.val.as_number = t;
    return res;
  endfunction

  function svs_node eval_arithmetic(svs_node ast);
    integer size = ast.val.as_seq.size();
    string fn = ast.val.as_seq[0].val.as_string;
    svs_node l;
    svs_node r;
    svs_node res;
    if(size < 3)
      return partial(ast, 3);
    if(size != 3)
      return new_exception(ast, {fn, " expects 2 arguments"});
    l = eval(ast.val.as_seq[1]);
    if(exception != null)
      return exception;
    if(l.typ != "number")
      return new_exception(ast, {fn, " expects a number as the first argument but got ", l.typ});
    r = eval(ast.val.as_seq[2]);
    if(exception != null)
      return exception;
    if(r.typ != "number")
      return new_exception(ast, {fn, " expects a number as the second argument but got ", r.typ});
    if(fn == "+") begin
      res = new_node(ast, "number");
      res.val.as_number = l.val.as_number + r.val.as_number;
    end else if(fn == "-") begin
      res = new_node(ast, "number");
      res.val.as_number = l.val.as_number - r.val.as_number;
    end else if(fn == "*") begin
      res = new_node(ast, "number");
      res.val.as_number = l.val.as_number * r.val.as_number;
    end else if(fn == "/") begin
      if(r.val.as_number == 0)
        return new_exception(ast, "/ get a 0 as the second argument");
      res = new_node(ast, "number");
      res.val.as_number = l.val.as_number / r.val.as_number;
    end else if(fn == ">") begin
      if(l.val.as_number > r.val.as_number)
        return true;
      else
        return false;
    end else if(fn == "<") begin
      if(l.val.as_number < r.val.as_number)
        return true;
      else
        return false;
    end else if(fn == ">=") begin
      if(l.val.as_number >= r.val.as_number)
        return true;
      else
        return false;
    end else if(fn == "<=") begin
      if(l.val.as_number <= r.val.as_number)
        return true;
      else
        return false;
    end
    return res;
  endfunction

  function svs_node eval_number_p(svs_node ast);
    integer size = ast.val.as_seq.size();
    svs_node n;
    if(size < 2)
      return partial(ast, 2);
    if(size != 2)
      return new_exception(ast, "number? expects 1 argument");
    n = eval(ast.val.as_seq[1]);
    if(exception != null)
      return exception;
    if(n.typ == "number")
      return true;
    else
      return false;
  endfunction

  function svs_node eval_do(svs_node ast, int tc);
    integer size = ast.val.as_seq.size();
    svs_node res;
    if(size < 3)
      return partial(ast, 3);
    if(size != 3)
      return new_exception(ast, "do expects 2 arguments");
    res = eval(ast.val.as_seq[1]);
    if(exception != null)
      return exception;
    if(ast.val.as_seq[2].typ == "list" && tc != `TC_RESET && enable_tco == 1)
      res = tco(ast.val.as_seq[2]);
    else begin
      res = eval(ast.val.as_seq[2], `TC_READY);
    end
    if(exception != null)
      return exception;
    return res;
  endfunction

  function int param_exists(svs_node ast);
    string typ = ast.typ;
    string str = ast.val.as_string;
    if(typ == "symbol") begin
      return stack.param_exists(str);
    end else
      return 0;
  endfunction

  function svs_node bind_param(svs_node ast);
    string typ = ast.typ;
    string str = ast.val.as_string;
    if(typ == "symbol") begin
      return stack.read_param(str);
    end else
      return new_exception(ast, {"expect a symbol but got ", typ});
  endfunction

  function svs_node bind_var(svs_node ast);
    string typ = ast.typ;
    string str = ast.val.as_string;
    if(typ == "symbol") begin
      if(stack.var_exists(str))
        return stack.read_var(str);
      return new_exception(ast, {"cannot find variable ", str});
    end else
      return new_exception(ast, {"expect a symbol but got ", typ});
  endfunction

  function svs_node bind_func(svs_node ast);
    string typ = ast.typ;
    string str = ast.val.as_string;
    //svs_node bf;
    if(typ == "symbol") begin
      if(primitives.exists(str)) begin
        //bf = new_node(ast, "function");
        //bf.val.as_string = str;
        return ast; // bf;
      end else if(stack.param_exists(str)) begin
        svs_node f = stack.read_param(str);
        if(f.typ == "symbol")
          return bind_func(f);
        else
          return f;
      end else begin
        if(stack.func_exists(str))
          return stack.read_func(str);
        return new_exception(ast, {"cannot find function ", str});
      end
    end else
      return new_exception(ast, {"expect a symbol but got ", typ});
  endfunction

endclass

`endif
