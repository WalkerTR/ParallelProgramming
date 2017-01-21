package sokoban.ipl;

import ibis.ipl.*;
import ibis.ipl.Ibis;
import ibis.ipl.IbisIdentifier;
import ibis.ipl.ReadMessage;
import ibis.ipl.ReceivePort;
import ibis.ipl.ReceivePortIdentifier;
import ibis.ipl.SendPort;
import ibis.ipl.WriteMessage;
import ibis.ipl.impl.*;

import java.io.IOException;
import java.util.*;

public class Master implements Runnable {

    private static final int MAXHOPS = 6;
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

            resultsPort.enableConnections();

            // synchronization point to ensure all results sendport are connected
            for (int i = 0; i < ibis.registry().getPoolSize(); i++) {
                resultsPort.receive().finish();
            }

            // run only if board is set
            if (board != null) {
                System.out.println("Running Sokoban, initial board:\n" + board);

                long start = System.currentTimeMillis();

                System.out.print("Bound now:");

                int bound = 0;
                int solutions;

                do {
                    bound++;
                    System.out.print(" " + bound);
                    solutions = 0;
                    List<Board> boards = new ArrayList<>();
                    Board init = cache.get(board);
                    boards.add(init);
                    init.setBound(bound);
                    for (int i = 0; i < bound && i < MAXHOPS; i++) {
                        List<Board> newBoards = new ArrayList<>();
                        for (Board b : boards) {
                            newBoards.addAll(b.generateChildren(cache));
                            cache.put(b);
                        }
                        boards = newBoards;
                    }
                    if (bound > MAXHOPS) {
                        Iterator<Board> it = boards.iterator();
                        int responses = 0;
                        for (SendPort port : pool.values()) {
                            if (it.hasNext()) {
                                WriteMessage message = port.newMessage();
                                message.writeObject(it.next());
                                message.finish();
                            }
                        }

                        while (it.hasNext()) {
                            ReadMessage rmessage = resultsPort.receive();
                            solutions += rmessage.readInt();
                            responses++;
                            rmessage.finish();

                            WriteMessage wmessage = pool.get(rmessage.origin().ibisIdentifier()).newMessage();
                            wmessage.writeObject(it.next());
                            wmessage.finish();
                        }

                        while (responses < boards.size()) {
                            ReadMessage message = resultsPort.receive();
                            solutions += message.readInt();
                            responses++;
                            message.finish();
                        }

                    } else {
                        for (Board b : boards) {
                            if (b.isSolved()) {
                                solutions++;
                            }
                        }
                    }

                } while (solutions == 0);

                System.out.println();
                System.out.println("Solving game possible in " + solutions + " ways of " + bound + " steps");

                long end = System.currentTimeMillis();

                System.err.println("Sokoban took " + (end - start) + " milliseconds");

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
