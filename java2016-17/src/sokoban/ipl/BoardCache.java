package sokoban.ipl;

/* class used for caching board objects, so we don't have to create new ones */
public class BoardCache {

	public static final int MAX_CACHE_SIZE = 10 * 1024;

	int size;
	sokoban.ipl.Board[] cache;

	public BoardCache() {
		size = 0;
		cache = new sokoban.ipl.Board[MAX_CACHE_SIZE];
	}

	public sokoban.ipl.Board get(sokoban.ipl.Board board) {
		if (size > 0) {
			size--;
			sokoban.ipl.Board result = cache[size];
			result.init(board);
			return result;
		} else {
			return new sokoban.ipl.Board(board);
		}
	}

	public void put(Board board) {
		if (board == null) {
			return;
		}
		if (size >= MAX_CACHE_SIZE) {
			return;
		}
		cache[size] = board;
		size++;
	}
}
