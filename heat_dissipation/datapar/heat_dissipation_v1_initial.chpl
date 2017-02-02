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
  const BigD = {0..N+1, 0..M+1};
  const D: subdomain(BigD) = {1..N, 1..M};
  const Halo = {-1..1, -1..1};
  
  const directWeight: real = (sqrt(2) / (sqrt(2) + 1)) / 4;
  const diagonalWeight: real = (1 / (sqrt(2) + 1)) / 4;
  var weights: [Halo] real;
  weights[-1,0] = directWeight;
  weights[0,-1] = directWeight;
  weights[0,1] = directWeight;
  weights[1,0] = directWeight;
  weights[-1,-1] = diagonalWeight;
  weights[-1,1] = diagonalWeight;
  weights[1,-1] = diagonalWeight;
  weights[1,1] = diagonalWeight;

  var A: [BigD] real;
  var Cond, Temp: [D] real;
  var r: results;
  var t: Timer;
  var it: int;
  var e: real;

  // matrix copy to ensure they match the domain D
  A[D] = tinit;
  Cond[D] = tcond;

  // copy of constant top-bottom cells
  A[D.exterior(-1,0)] = A[D.interior(-1,0)];
  A[D.exterior(1,0)] = A[D.interior(1,0)];

  // copy of the four corners
  M1[0, 0] = M1[0, M];
  M1[N+1, 0] = M1[N+1, M];
  M1[0, M+1] = M1[0, 1];
  M1[N+1, M+1] = M1[N+1, 1];

  t.start();
  do {
    // copy of left-right columns
    A[1..N, 0..0] = A[1..N, M..M];
    A[1..N, M+1..M+1] = A[1..N, 1..1];

    // computing new values
    forall idx in D {
      const halo = weights * A[Halo.translate(idx)];
      Temp[idx] = + reduce halo;
      Temp[idx] *= 1 - Cond[idx];
      Temp[idx] += Cond[idx] * A[idx];
    }

    it = it + 1;

    // computing maximum difference
    e = max reduce abs(A[D] - Temp[D]);

    // storing new values
    A[D] = Temp[D];
  } while(it < I && e > E);
  t.stop();

  r.tmin = min reduce A[D];
  r.tmax = max reduce A[D];
  r.maxdiff = e;
  r.niter = it;
  r.tavg = + reduce A[D] / D.size;
  r.time = t.elapsed();

  return r;
}

/* End add your code here */

util.main();