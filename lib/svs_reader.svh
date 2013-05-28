`ifndef __SVS_READER_SVH__
`define __SVS_READER_SVH__
`include "svs_node.svh"
`include "svs_logger.svh"

`define EOF -1

class svs_reader;

  svs_node ast; 
  integer fid;
  string filename;
  integer line;
  integer col; 

  function new();
    ast = new("list");
    line = 1;
    col = 1;
  endfunction

  function error(string msg="");
    string nmsg;
    $sformat(nmsg, "%s [file: %s; line: %d; col: %d]", msg, filename, line, col);
    `SVS_ERROR(nmsg)
  endfunction

  function integer peek_char(integer l=1);
    integer c;
    integer i;
    integer r;
    for(i=0; i<l; i++) begin
      c = $fgetc(fid);
    end
    if(c != `EOF) 
      r = $fseek(fid, 0-l, 1);
    return c;
  endfunction

  function integer get_char();
    integer c = $fgetc(fid);
    return c;
  endfunction

  function void consume();
    integer c = $fgetc(fid);
    if(c == "\n") begin
      line = line + 1;
      col = 1;
    end else begin
      col = col + 1;
    end
  endfunction

  function void skip_blankspace();
    integer c = peek_char();
    while(c != `EOF) begin
      if(c == " " || c == "\t" || c == "\n")
        consume();
      else
        break;
      c = peek_char();
    end
  endfunction

  function svs_node read_file(string file);
    integer c;
    filename = file;
    line = 1;
    col = 1;
    ast.filename = file;
    ast.line = line;
    ast.col  = col;
    fid = $fopen(file, "r");
    if(fid == 0) begin
      error({"cannot open file ", file});
    end
    skip_blankspace();
    c = peek_char();
    while(c != `EOF) begin
      ast.val.as_seq.push_back(lex());
      skip_blankspace();
      c = peek_char();
    end
    return ast;
  endfunction

  function svs_node lex();
    integer c;
    skip_blankspace();
    c = peek_char();
    if(c == "(") begin
      return alist();
    end else if(c == ")") begin
      error("unmatched )");
    end else if(c == "\"") begin
      return astring();
    end else if((c >= 48 && c <= 57) ||
                ((c == "+" || c == "-") &&
                 peek_char(2) >= 48 && peek_char(2) <= 57)) begin
      return anumber();
    end else begin
      return asymbol();
    end
  endfunction

  function svs_node alist();
    svs_node l;
    integer c;
    consume();
    skip_blankspace();
    l = new("list");
    l.filename = filename;
    l.line = line;
    l.col  = col;
    c = peek_char();
    while(c != `EOF && c != ")") begin
      l.val.as_seq.push_back(lex());
      skip_blankspace();
      c = peek_char();
    end
    if(c != ")") begin
      error("expected )");
    end
    consume();
    return l;
  endfunction

  function svs_node astring();
    svs_node s;
    integer c;
    consume();
    s = new("string");
    s.filename = filename;
    s.line = line;
    s.col  = col;
    c = peek_char();
    while(c != `EOF && c != "\"") begin
      if(c == "\\") begin
        consume();
        c = peek_char();
        if(c == "n")
          s.val.as_string = {s.val.as_string, "\n"};
        else if(c == "t")
          s.val.as_string = {s.val.as_string, "\t"};
        else if(c == "b")
          s.val.as_string = {s.val.as_string, "\b"};
        else if(c == "e")
          s.val.as_string = {s.val.as_string, "\e"};
        else if(c == "r")
          s.val.as_string = {s.val.as_string, "\r"};
        else
          s.val.as_string = {s.val.as_string, string'(c)};
        consume();
      end else begin
        s.val.as_string = {s.val.as_string, string'(c)};
        consume();
      end
      c = peek_char();
    end
    if(c != "\"") begin
      error("expected \"");
    end
    consume();
    return s;
  endfunction

  function svs_node anumber();
    svs_node n = new("number");
    integer c = peek_char();
    real dot = 0;
    n.filename = filename;
    n.line = line;
    n.col  = col;
    if(c == "+") begin
      n.val.as_string = {n.val.as_string, string'(c)};
      consume();
      c = peek_char();
    end
    else if(c == "-") begin
      n.val.as_string = {n.val.as_string, string'(c)};
      consume();
      c = peek_char();
    end
    while(c != `EOF &&
          c != " " && c != "\t" && c != "\n" &&
          c != "(" && c != ")" && c != "\"") begin
      if(c == "0" || c == "1" || c == "2" || c == "3" || c == "4" || c == "5" || c == "6" ||
         c == "7" || c == "8" || c == "9" ||
         c == ".") begin
        n.val.as_string = {n.val.as_string, string'(c)};
        if(c == ".")
          dot = 1;
        else if(dot == 1 && c == ".") begin
          error("invalid double letter . for number");
        end
        //  dot = dot * 0.1;
        //  n.val.as_number = n.val.as_number + (c-integer'("0")) * dot;
        //end else if(dot == 0)
        //  n.val.as_number = n.val.as_number * 10 + (c-integer'("0"));
	consume();
        c = peek_char();
      end else begin
        error({"invalid letter ", string'(c), " for number"});
        $finish();
      end
    end
    n.val.as_number = n.val.as_string.atoreal();
    return n;
  endfunction

  function svs_node asymbol();
    svs_node s = new("symbol");
    integer c = peek_char();
    s.filename = filename;
    s.line = line;
    s.col  = col;
    while(c != `EOF &&
          c != " " && c != "\t" && c != "\n" &&
          c != "(" && c != ")" && c != "\"") begin
      if(c == "a" || c == "b" || c == "c" || c == "d" || c == "e" || c == "f" || c == "g" ||
         c == "h" || c == "i" || c == "j" || c == "k" || c == "l" || c == "m" || c == "n" ||
         c == "o" || c == "p" || c == "q" || c == "r" || c == "s" || c == "t" || c == "u" ||
         c == "v" || c == "w" || c == "x" || c == "y" || c == "z" || 
         c == "A" || c == "B" || c == "C" || c == "D" || c == "E" || c == "F" || c == "G" ||
         c == "H" || c == "I" || c == "J" || c == "K" || c == "L" || c == "M" || c == "N" ||
         c == "O" || c == "P" || c == "Q" || c == "R" || c == "S" || c == "T" || c == "U" ||
         c == "V" || c == "W" || c == "X" || c == "Y" || c == "Z" ||
         c == "=" || c == "-" || c == "*" || c == "/" || c == "+" || c == "_" || c == "?" ||
         c == "$" || c == "!" || c == "@" || c == "~" || c == "." || c == ">" || c == "<" ||
         c == "&" || c == "%" || c == "'" || c == "#" || c == "`" || c == ";" || c == ":" ||
         c == "{" || c == "}" ||
         c == "0" || c == "1" || c == "2" || c == "3" || c == "4" || c == "5" || c == "6" ||
         c == "7" || c == "8" || c == "9") begin
        s.val.as_string = {s.val.as_string, string'(c)};
        consume();
        c = peek_char();
      end else begin
        error({"invalid letter ", string'(c), " for symbol"});
        $finish();
      end
    end
    return s;
  endfunction

endclass

`endif
