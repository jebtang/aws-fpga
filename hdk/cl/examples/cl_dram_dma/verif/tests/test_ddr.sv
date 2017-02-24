// =============================================================================
// Copyright 2016 Amazon.com, Inc. or its affiliates.
// All Rights Reserved Worldwide.
// Amazon Confidential information
// Restricted NDA Material
// =============================================================================

module test_ddr();

   logic [63:0]   base_addr;

   int            error_count;
   int            fail;

   initial begin
      error_count = 0;
      fail = 0;

      tb.sh.power_up();
      tb.sh.delay(500);
      tb.sh.poke_stat(.stat_addr(8'h0c), .ddr_idx(0), .data(32'h0000_0000));
      tb.sh.poke_stat(.stat_addr(8'h0c), .ddr_idx(1), .data(32'h0000_0000));
      tb.sh.poke_stat(.stat_addr(8'h0c), .ddr_idx(2), .data(32'h0000_0000));

      // NOTE: All of the DDR controllers are ready at about the same time
      $display("[%t] : Waiting for DDR initialization", $realtime);
      wait (tb.CL.all_ddr_is_ready[0]);

      //---------------------------
      // Program CL registers and start reads and writes
      //---------------------------

      // DDR 0
      $display("[%t] : Programming cl_tst registers for DDR 0", $realtime);
      base_addr = 64'h0000_0000_0000_0100;
      ddr_common_test(.base_addr(base_addr), .error_count(error_count));

`ifdef VCS_SIM
      // DDR 1
      $display("[%t] : Programming cl_tst registers for DDR 1", $realtime);
      base_addr = 64'h0000_0000_0000_0200;
      ddr_common_test(.base_addr(base_addr), .error_count(error_count));

      // DDR 2
      $display("[%t] : Programming cl_tst registers for DDR 2", $realtime);
      base_addr = 64'h0000_0000_0000_0300;
      ddr_common_test(.base_addr(base_addr), .error_count(error_count));

      // DDR 3
      $display("[%t] : Programming cl_tst registers for DDR 3", $realtime);
      base_addr = 64'h0000_0000_0000_0400;
      ddr_common_test(.base_addr(base_addr), .error_count(error_count));
`endif

      // Power down
      #500ns;
      tb.sh.power_down();

      //---------------------------
      // Report pass/fail status
      //---------------------------
      $display("[%t] : Checking total error count...", $realtime);
      if (error_count > 0) begin
         fail = 1;
      end
      $display("[%t] : Detected %3d errors during this test", $realtime, error_count);

      if (fail) begin
         $display("[%t] : *** TEST FAILED ***", $realtime);
      end else begin
         $display("[%t] : *** TEST PASSED ***", $realtime);
      end

      $finish;
   end

   task automatic ddr_common_test(input logic [63:0] base_addr,
                                  logic [63:0]       test_addr = 64'ha987_6543_2100_0000,
                                  logic [31:0]       test_data = 32'h6c93_af50,
                                  ref int            error_count
                                 );
      begin
         logic [31:0]   write_data;
         logic [31:0]   read_data;

         logic [63:0]   cycle_count;
         logic [63:0]   error_addr;

         logic [3:0]    error_index;

         int            timeout_count;

         // CL Config
         write_data = 32'h0100_0018; // Enable Incr ID mode, Sync mode, and Read Compare
         tb.sh.poke(.addr(base_addr + 64'h000), .data(write_data), .intf(2));

         // Set the max number of read requests
         tb.sh.poke(.addr(base_addr + 64'h014), .data(32'h0000_000f), .intf(2));

         // Initial write index
         tb.sh.poke(.addr(base_addr + 64'h01c), .data(32'h0000_0000), .intf(2));

         // Addr low
         tb.sh.poke(.addr(base_addr + 64'h020), .data(test_addr[31:0]), .intf(2));

         // Addr high
         tb.sh.poke(.addr(base_addr + 64'h024), .data(test_addr[63:32]), .intf(2));

         // Write data
         tb.sh.poke(.addr(base_addr + 64'h028), .data(test_data[31:0]), .intf(2));

         // Write user and instruction length
         tb.sh.poke(.addr(base_addr + 64'h02c), .data(32'h0000_0007), .intf(2));

         // Initial read index
         tb.sh.poke(.addr(base_addr + 64'h03c), .data(32'h0000_0000), .intf(2));

         // Addr low
         tb.sh.poke(.addr(base_addr + 64'h040), .data(test_addr[31:0]), .intf(2));

         // Addr high
         tb.sh.poke(.addr(base_addr + 64'h044), .data(test_addr[63:32]), .intf(2));

         // Read data (same as write data)
         tb.sh.poke(.addr(base_addr + 64'h048), .data(test_data[31:0]), .intf(2));

         // Read user and instruction length
         tb.sh.poke(.addr(base_addr + 64'h04c), .data(32'h0000_0007), .intf(2));

         // Number of instructions ([31:16] for read, [15:0] for write)
         tb.sh.poke(.addr(base_addr + 64'h010), .data(32'h0000_0000), .intf(2));

         $display("[%t] : Starting DDR write and read activity from cl_tst", $realtime);

         // Start reads and writes ([1] for reads, [0] for writes)
         tb.sh.poke(.addr(base_addr + 64'h008), .data(32'h0000_0003), .intf(2));

         // Wait for writes and reads to complete
         #5000ns;

         $display("[%t] : Waiting for DDR write and read activity to complete", $realtime);

         timeout_count = 0;
         do begin
            tb.sh.peek(.addr(base_addr + 64'h008), .data(read_data), .intf(2));
            timeout_count++;
         end while ((read_data[2:0] !== 3'b000) && (timeout_count < 100));

         if ((timeout_count == 100) && (read_data[2:0] !== 3'b000)) begin
            $display("[%t] : *** ERROR *** Timeout waiting for writes and reads to complete.", $realtime);
            error_count++;
         end else begin
            // Stop reads and writes ([1] for reads, [0] for writes)
            tb.sh.poke(.addr(base_addr + 64'h008), .data(32'h0000_0000), .intf(2));

            $display("[%t] : Checking some register values", $realtime);

            cycle_count = 64'h0;
            // Check that the write timer value is non-zero
            tb.sh.peek(.addr(base_addr + 64'h0f0), .data(read_data), .intf(2));
            cycle_count[31:0] = read_data;
            tb.sh.peek(.addr(base_addr + 64'h0f4), .data(read_data), .intf(2));
            cycle_count[63:32] = read_data;
            if (cycle_count == 64'h0) begin
               $display("[%t] : *** ERROR *** Write Timer value was 0x0 at end of test.", $realtime);
               error_count++;
            end

            cycle_count = 64'h0;
            // Check that the read timer value is non-zero
            tb.sh.peek(.addr(base_addr + 64'h0f8), .data(read_data), .intf(2));
            cycle_count[31:0] = read_data;
            tb.sh.peek(.addr(base_addr + 64'h0fc), .data(read_data), .intf(2));
            cycle_count[63:32] = read_data;
            if (cycle_count == 64'h0) begin
               $display("[%t] : *** ERROR *** Read Timer value was 0x0 at end of test.", $realtime);
               error_count++;
            end

            $display("[%t] : Checking for read compare errors", $realtime);

            // Check for compare error
            tb.sh.peek(.addr(base_addr + 64'h0b0), .data(read_data), .intf(2));
            if (read_data != 32'h0000_0000) begin
               tb.sh.peek(.addr(base_addr + 64'h0b4), .data(read_data), .intf(2));
               error_addr[31:0] = read_data;
               tb.sh.peek(.addr(base_addr + 64'h0b8), .data(read_data), .intf(2));
               error_addr[63:32] = read_data;
               tb.sh.peek(.addr(base_addr + 64'h0bc), .data(read_data), .intf(2));
               error_index = read_data[3:0];
               $display("[%t] : *** ERROR *** Read compare error from address 0x%016x, index 0x%1x", $realtime, error_addr, error_index);
               error_count++;
            end
         end

      end
   endtask

endmodule // test_ddr