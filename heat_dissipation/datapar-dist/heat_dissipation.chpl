use util;
use Time;

config const N = 150;
config const M = 100;
config const I = 42;
config const E = 0.1;
config const L = -100.0;
config const H = 100.0;
config const P = 1;
config const C = "/home/hphijma/images/pat1_150x100.pgm";
config const T = "/home/hphijma/images/pat2_150x100.pgm";
config const help_params = false;

/* Add your code here */

print_parameters();

const tinit: [1..N, 1..M] real;
readpgm(T, N, M, {1..N, 1..M}, tinit, L, H);

const tcond: [1..N, 1..M] real;
readpgm(C, N, M, {1..N, 1..M}, tcond, 0.0, 1.0);

proc do_compute() {
  /* your main function */
  var r : results;
  var t : Timer;

  t.start();
  writeln(tinit);
  t.stop();

  r.tmin = 0.0;
  r.tmax = 0.0;
  r.maxdiff = 0.0;
  r.niter = 0;
  r.tavg = 0.0;
  r.time = t.elapsed();

  return r;
}

/* End add your code here */

util.main();