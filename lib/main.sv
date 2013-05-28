`include "svs_evaler.svh"

program svs_repl;
  svs_evaler se;
  string path;
  string shenpath;
  initial begin
    se = new;
    path = `__FILE__;
    path = path.substr(0, path.len()-0);
    shenpath = {path, "../shen/release/k_lambda/"};
    se.load_file({path, "boot.kl"});
    se.load_file({shenpath, "toplevel.kl"});
    se.load_file({shenpath, "core.kl"});
    se.load_file({shenpath, "sys.kl"});
    se.load_file({shenpath, "sequent.kl"});
    se.load_file({shenpath, "yacc.kl"});
    se.load_file({shenpath, "reader.kl"});
    se.load_file({shenpath, "prolog.kl"});
    se.load_file({shenpath, "track.kl"});
    se.load_file({shenpath, "load.kl"});
    se.load_file({shenpath, "writer.kl"});
    se.load_file({shenpath, "macros.kl"});
    se.load_file({shenpath, "declarations.kl"});
    se.load_file({shenpath, "types.kl"});
    se.load_file({shenpath, "t-star.kl"});
    se.load_file({path, "svsrepl.kl"});
  end
endprogram
