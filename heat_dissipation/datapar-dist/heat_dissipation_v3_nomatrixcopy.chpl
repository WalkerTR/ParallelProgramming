use util;
use Time;
use BlockDist;

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
  const BigD = {0..N+1, 0..M+1} dmapped Block(boundingBox={0..N+1, 0..M+1});
  const D: subdomain(BigD) = {1..N, 1..M};
  const COL: subdomain(BigD) = D.exterior(0,-1);
  
  const directWeight: real = (sqrt(2) / (sqrt(2) + 1)) / 4;
  const diagonalWeight: real = (1 / (sqrt(2) + 1)) / 4;

  var M1, M2: [BigD] real;
  var Cond, ABS: [D] real;
  var r: results;
  var t: Timer;
  var it: int;
  var e: real;

  // matrix copy to ensure they match the domain D
  M1[D] = tinit;
  Cond[D] = tcond;

  // copy of constant top-bottom cells
  M1[D.exterior(-1,0)] = M1[D.interior(-1,0)];
  M1[D.exterior(1,0)] = M1[D.interior(1,0)];

  // copy of the four corners
  M1[0, 0] = M1[0, M];
  M1[N+1, 0] = M1[N+1, M];
  M1[0, M+1] = M1[0, 1];
  M1[N+1, M+1] = M1[N+1, 1];

  // copy of the fixed cells to the other matrix
  M2[BigD.interior(-1,0)] = M1[BigD.interior(-1,0)];
  M2[BigD.interior(1,0)] = M1[BigD.interior(1,0)];

  t.start();
  do {
    if (it % 2 == 0) {
      // copy of left-right columns
      forall (i, j) in COL {
        M1[i, 0] = M1[i, M];
        M1[i, M+1] = M1[i, 1];
      }

      // computing new values
      forall (i, j) in D {
        M2[i, j] = Cond[i, j] * M1[i, j]
                  + (1 - Cond[i, j]) * (
                        diagonalWeight * (M1[i-1, j-1] +
                                          M1[i-1, j+1] +
                                          M1[i+1, j-1] +
                                          M1[i+1, j+1])
                        +
                        directWeight * (M1[i-1, j] +
                                        M1[i, j-1] +
                                        M1[i, j+1] +
                                        M1[i+1, j])
                  );
      }
    } else {
      // copy of left-right columns
      forall (i, j) in COL {
        M2[i, 0] = M2[i, M];
        M2[i, M+1] = M2[i, 1];
      }

      // computing new values
      forall (i, j) in D {
        M1[i, j] = Cond[i, j] * M2[i, j]
                  + (1 - Cond[i, j]) * (
                        diagonalWeight * (M2[i-1, j-1] +
                                          M2[i-1, j+1] +
                                          M2[i+1, j-1] +
                                          M2[i+1, j+1])
                        +
                        directWeight * (M2[i-1, j] +
                                        M2[i, j-1] +
                                        M2[i, j+1] +
                                        M2[i+1, j])
                  );
      }
    }

    it = it + 1;

    // computing maximum difference
    forall idx in D do ABS[idx] = abs(M1[idx] - M2[idx]);
    e = max reduce ABS;
  } while(it < I && e > E);
  t.stop();

  r.maxdiff = e;
  r.niter = it;
  r.time = t.elapsed();

  if (it % 2 == 0) {
    r.tmin = min reduce M1[D];
    r.tmax = max reduce M1[D];
    r.tavg = + reduce M1[D] / D.size;
  } else {
    r.tmin = min reduce M2[D];
    r.tmax = max reduce M2[D];
    r.tavg = + reduce M2[D] / D.size;
  }

  return r;
}

/* End add your code here */

util.main();