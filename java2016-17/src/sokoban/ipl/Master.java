package sokoban.ipl;

import ibis.ipl.*;

import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;

public class Master implements Runnable {

    private static final int MINJOBS = 1000;
    private static BoardCache cache = new BoardCache();

    private Ibis ibis;
    private Board board;
    private ReceivePort greetsPort;
    private ReceivePort resultsPort;

    private HashMap<IbisIdentifier, SendPort> pool = new HashMap<>();


    public Master(Ibis ibis, Board board) throws IOException{
        this.ibis = ibis;
        this.board = board;

        resultsPort = ibis.createReceivePort(Sokoban.resultsPortType, "results");
        greetsPort = ibis.createReceivePort(Sokoban.greetsPortType, "greets");

    }

    @Override
    public void run() {
        try {
            resultsPort.enableConnections();

            // greetings - sync point
            greetsPort.enableConnections();
            for (int i = 0; i < ibis.registry().getPoolSize(); i++) {
                ReadMessage message = greetsPort.receive();
                ReceivePortIdentifier port = (ReceivePortIdentifier) message.readObject();
                message.finish();

                SendPort replyPort = ibis.createSendPort(Sokoban.jobSubmitPortType);
                replyPort.connect(port);
                pool.put(message.origin().ibisIdentifier(), replyPort);
            }
            greetsPort.disableConnections();

            // run only if board is set
            if (board != null) {
                System.out.println("Running Sokoban, initial board:\n" + board);

                long start = System.currentTimeMillis();

                System.out.print("Bound now:");

                int bound = 0;
                int solutions = 0;

                //long ta=0,tb=0,tc=0,td=0,te=0;

                do {
                    bound++;
                    System.out.print(" " + bound);
                    List<Board> boards = new ArrayList<>();
                    Board init = cache.get(board);
                    boards.add(init);
                    init.setBound(bound);
                    //ta -= System.currentTimeMillis();
                    for (int i = 0; i < bound && boards.size() < MINJOBS; i++) {
                        List<Board> newBoards = new ArrayList<>();
                        for (Board b : boards) {
                            newBoards.addAll(b.generateChildren(cache));
                            cache.put(b);
                        }
                        boards = newBoards;
                    }
                    //ta += System.currentTimeMillis();
                    if (boards.size() >= MINJOBS) {
                        Iterator<Board> it = boards.iterator();
                        int responses = 0;

                        //tb -= System.currentTimeMillis();
                        for (SendPort port : pool.values()) {
                            if (it.hasNext()) {
                                WriteMessage message = port.newMessage();
                                message.writeObject(it.next());
                                message.finish();
                            }
                        }
                        //tb += System.currentTimeMillis();

                        //tc -= System.currentTimeMillis();
                        while (it.hasNext()) {
                            ReadMessage rmessage = resultsPort.receive();
                            solutions += rmessage.readInt();
                            rmessage.finish();
                            responses++;

                            Board b = it.next();
                            WriteMessage wmessage = pool.get(rmessage.origin().ibisIdentifier()).newMessage();
                            wmessage.writeObject(b);
                            wmessage.finish();
                            cache.put(b);
                        }
                        //tc += System.currentTimeMillis();

                        //td -= System.currentTimeMillis();
                        while (responses < boards.size()) {
                            ReadMessage message = resultsPort.receive();
                            solutions += message.readInt();
                            responses++;
                            message.finish();
                        }
                        //td += System.currentTimeMillis();

                    } else {
                        //te -= System.currentTimeMillis();
                        for (Board b : boards) {
                            if (b.isSolved()) {
                                solutions++;
                            }
                            cache.put(b);
                        }
                        //te += System.currentTimeMillis();
                    }

                } while (solutions == 0);

                System.out.println();
                System.out.println("Solving game possible in " + solutions + " ways of " + bound + " steps");

                long end = System.currentTimeMillis();

                System.err.println("Sokoban took " + (end - start) + " milliseconds");

                /*
                System.err.println();
                System.err.println();
                System.err.println("TIMINGS");
                System.err.println("A: " + ta);
                System.err.println("B: " + tb);
                System.err.println("C: " + tc);
                System.err.println("D: " + td);
                System.err.println("E: " + te);
                */

            }

            // terminating workers
            for (SendPort port : pool.values()) {
                WriteMessage message = port.newMessage();
                message.writeObject(null);
                message.finish();
                port.close();
            }
            resultsPort.close();

        } catch (IOException e) {
            e.printStackTrace();
        } catch (ClassNotFoundException e) {
            e.printStackTrace();
        }
    }

}
