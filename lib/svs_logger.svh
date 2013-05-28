`ifndef __SVS_LOGGER_SVH__
`define __SVS_LOGGER_SVH__

`define SVS_ERROR(msg) \
  begin \
    $display("ERROR: %s", msg); \
    $finish(); \
  end

`endif
