#!/bin/perl
use strict;

my @lines;
my @asts;
my @vars;

open FH, "<stim" or die "Fail";
@lines = <FH>;
close FH;

open FH, "<ast.sv" or die "Fail";
@asts = <FH>;
close FH;

for(@lines) {
    push @vars, parse_line($_);
}

my $declare_vars_str = "";
for my $var (@vars) {
    $declare_vars_str .= i_line("logic $var->[0];", 1);
}

my $assignment_vars_str = "";
for my $var (@vars) {
    $assignment_vars_str .= i_line("begin : blk_$var->[0]", 3);
    $assignment_vars_str .= i_line("$var->[0] = 0;", 4);
    for my $value (@{$var->[1]}) {
        $assignment_vars_str .= i_line("#1 $var->[0] = $value;", 4);
    }
    $assignment_vars_str .= i_line("end", 3);
}

my $ast_str = "";
for my $ast (@asts) {
    chomp($ast);
    $ast_str .= i_line($ast, 1);
}

open FH, ">ast_test.sv";
print FH <<EOF;
`timescale 1ns/1ps
module tb;
    bit clk;
    always #0.5 clk = ~clk;

    initial begin
        \$fsdbDumpfile(\"ast_test.fsdb\");
        \$fsdbDumpvars(0, tb);
    end
    
$declare_vars_str
    initial begin
        fork
$assignment_vars_str
            #200 \$finish;
        join
    end

// ========================================================================== //

$ast_str
endmodule
EOF
close FH;

# refer to VCS UG for detail about assert related options
system("vcs -full64 -sverilog -debug_access+r -assert enable_diag -kdb ast_test.sv");
system("./simv -l vcs_run.log +fsdb+sva_success -gui=verdi &");

# ---------------------------------------------------------------------------- #
sub parse_line {
    my $line = shift;
    my ($name, $values_str) = split(/\s/, $line);
    my @values = split(//, $values_str);
    return [$name, \@values];
}

sub i_line {
    my $line = shift;
    my $i = shift;
    return "    "x$i . $line . "\n";
}

