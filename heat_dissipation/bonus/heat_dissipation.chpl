use util;
use Time;
use Barrier;

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

class TopBottom {
  var top, bottom: [{1..1, 0..M+1}] real;
}

proc do_compute() {
  // shared variables
  var r: results;
  var exit: bool;
  var lock: sync bool;
  var b = new Barrier(numLocales);

  // setting results to minimum
  r.tmin = H;
  r.tmax = L;

  const directWeight: real = (sqrt(2) / (sqrt(2) + 1)) / 4;
  const diagonalWeight: real = (1 / (sqrt(2) + 1)) / 4;

  // references for communication
  var rows: [LocaleSpace] TopBottom;


  // spawning the execution on locales
  // the variabile with side effects (non sync)
  // must be passed by reference
  coforall loc in Locales with (ref r, ref exit) {
    on loc {
      // creating local object and saving reference
      // in the shared array
      rows[here.id] = new TopBottom();

      // local variables
      var startIdx, endIdx: int = 1;
      var it: int;
      var delta: real;
      var t: Timer;

      // computing local part of the matrix
      while (floor((startIdx-1)*numLocales / N) < here.id) {
        startIdx = startIdx + 1;
      }
      while (floor(endIdx*numLocales / N) <= here.id) {
        endIdx = endIdx + 1;
      }
      const numRows: int = endIdx - startIdx + 1;

      // domains with respect to the local part
      // of the matrix
      const BigD = {0..numRows+1, 0..M+1};
      const D = {1..numRows, 1..M};

      // local matrices declaration
      var M1, M2: [BigD] real;
      var C, ABS: [D] real;

      // copy of the submatrix in this locale
      M1[D] = tinit[startIdx..endIdx, 1..M];
      C[D] = tcond[startIdx..endIdx, 1..M];

      // before accessing the shared array
      // every locale must have saved its reference
      b.barrier();

      // the top row of the locale 0 is fixed
      if (here.id == 0) {
        M1[1, 0] = M1[1, M];
        M1[1, M+1] = M1[1, 1];
        rows[here.id].top = M1[1..1, 0..M+1];
      }
      // the bottom row of the last local is fixed
      if (here.id == numLocales-1) {
        M1[numRows, 0] = M1[numRows, M];
        M1[numRows, M+1] = M1[numRows, 1];
        rows[here.id].bottom = M1[numRows..numRows, 0..M+1];
      }

      t.start();
      do {
        // before changing exit every locale
        // must have pass the loop condition
        b.barrier();

        if (here.id == 0) {
          exit = true;
        }

        if (it % 2 == 0) {
          // left-right boundary copy
          M1[1..numRows, 0..0] = M1[1..numRows, M..M];
          M1[1..numRows, M+1..M+1] = M1[1..numRows, 1..1];

          // remote write of top-bottom rows
          if (here.id > 0) {
            rows[here.id-1].bottom = M1[1..1, 0..M+1];
          }
          if (here.id < numLocales - 1) {
            rows[here.id+1].top = M1[numRows..numRows, 0..M+1];
          }

          // waiting for the end of "communication"
          b.barrier();

          // copying top-bottom rows to the matrix
          M1[0..0, 0..M+1] = rows[here.id].top;
          M1[numRows+1..numRows+1, 0..M+1] = rows[here.id].bottom;

          local forall (i, j) in D {
            // computing new value
            M2[i, j] = C[i, j] * M1[i, j]
                        + (1 - C[i, j]) * (
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
            // computing difference
            ABS[i, j] = abs(M1[i, j] - M2[i, j]);
          }
        } else {
          // left-right boundary copy
          M2[1..numRows, 0..0] = M2[1..numRows, M..M];
          M2[1..numRows, M+1..M+1] = M2[1..numRows, 1..1];

          // remote write of top-bottom rows
          if (here.id > 0) {
            rows[here.id-1].bottom = M2[1..1, 0..M+1];
          }
          if (here.id < numLocales - 1) {
            rows[here.id+1].top = M2[numRows..numRows, 0..M+1];
          }

          // waiting for the end of "communication"
          b.barrier();

          // copying top-bottom rows to the matrix
          M2[0..0, 0..M+1] = rows[here.id].top;
          M2[numRows+1..numRows+1, 0..M+1] = rows[here.id].bottom;

          local forall (i, j) in D {
            // computing new value
            M1[i, j] = C[i, j] * M2[i, j]
                        + (1 - C[i, j]) * (
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
            // computing difference
            ABS[i, j] = abs(M1[i, j] - M2[i, j]);
          }
        }

        it = it + 1;

        // computing maximum difference
        delta = max reduce ABS;

        // inform other local if not converged
        if (delta > E) {
          lock = true;
          exit = false;
          var unlock = lock;
        }

        // waiting for every locale to check
        // the convergence criterion
        b.barrier();

      } while (it < I && !exit);
      t.stop();

      var local_r: results;

      local_r.maxdiff = delta;
      local_r.time = t.elapsed();

      if (it % 2 == 0) {
        local_r.tmin = min reduce M1[D];
        local_r.tmax = max reduce M1[D];
        local_r.tavg = + reduce M1[D] / (M*N);
      } else {
        local_r.tmin = min reduce M2[D];
        local_r.tmax = max reduce M2[D];
        local_r.tavg = + reduce M2[D] / (M*N);
      }


      lock = true;

      if (local_r.tmin < r.tmin) then r.tmin = local_r.tmin;
      if (local_r.tmax > r.tmax) then r.tmax = local_r.tmax;
      if (local_r.maxdiff > r.maxdiff) then r.maxdiff = local_r.maxdiff;
      r.niter = it;
      r.tavg = r.tavg + local_r.tavg;
      if (local_r.time > r.time) then r.time = local_r.time;

      var unlock = lock;

    }
  }

  return r;
}



/* End add your code here */

util.main();