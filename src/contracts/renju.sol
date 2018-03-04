pragma solidity ^0.4.0;

// TODO: check the moves are not disallowed
// TODO: forbid to join the game without paying enough money

contract Renju {

    enum Player { FIRST, SECOND }

    struct Move {
        int8 row;
        int8 column;
    }

    struct FifthMoveProposal {
        // indicates whether this structure instance contains user-provided data
        // or is initialized with zero bytes by default
        bool isProvided;
        Move[2] options;
    }

    enum Cell { EMPTY, OCCUPIED_BY_FIRST_PLAYER, OCCUPIED_BY_SECOND_PLAYER }

    enum GameStatus { NOT_STARTED, IN_PROGRESS, FIRST_PLAYER_WON, SECOND_PLAYER_WON, DRAW }

    // ----------------- end of enum/struct declarations

    address firstPlayer_;

    address secondPlayer_;

    // the 1-based index of the last performed turn. The first turn is performed at the contract creation
    uint8 public lastTurnNumber_ = 1;

    // indicates which player has to perform the next action in the game.
    // The action could be a move, a pass or some special activity in the
    // opening(like color selection).
    //
    // the very first move is performed implicitly by the first player at the moment
    // of the contract creation
    Player nextTurnPlayer_ = Player.SECOND;

    bool isColorPickFinished_ = false;

    FifthMoveProposal FifthMoveProposal_;

    GameStatus gameStatus_ = GameStatus.NOT_STARTED;

    Cell[15][15] board_;

    // ------------------ end of field declarations

    // fuck you guys who decided that to use the contract name for constructor declaration is a good idea in 2014...
    function Renju() public {
        firstPlayer_ = msg.sender;
        for (uint8 i = 0; i < 15; i++) {
            for (uint8 j = 0; j < 15; j++) {
                board_[i][j] = Cell.EMPTY;
            }
        }
        board_[7][7] = FIRST_PLAYER_OCCUPIED; // make the very first move
    }

    // ------------ actions

    function joinTheGame() public {
        require(gameStatus_ == GameStatus.NOT_STARTED);
        require(msg.sender != firstPlayer_);

        secondPlayer_ = msg.sender;
        gameStatus_ = GameStatus.IN_PROGRESS;
    }

    function makeMove(uint8 line, uint8 column) public isSendersTurn()  {
        Move move = Move(line, column);
        if (lastTurnNumber_ == 1) {
            require(6 <= move.row    && move.row    <= 8);
            require(8 <= move.column && move.column <= 8);
        } else if (lastTurnNumber == 2) {
            require(5 <= move.row    && move.row    <= 9);
            require(5 <= move.column && move.column <= 9);
        } else {
            require(lastTurnNumber_ >= 5); // the fifth turn is performed via a separate function
        }
        doMakeMove(move);
    }

    function pickColor(bool whiteColorIsChosen) public isSendersTurn() {
        // TODO: implement
    }

    function suggestFifthMove(uint8 line1, uint8 column1, uint8 line2, uint8 column2)
            public isSendersTurn() {
        // TODO: implement
    }

    function selectFifthMove(uint8 line, uint8 column) public isSendersTurn() {
        // TODO: implement
    }

    function pass() public isSendersTurn() {
        // TODO: implement
    }

    // ---------- getters and stuff

    // Possible values:
    //     * 0 --- the game is not started yet
    //     * 1 --- the game is in process now
    //     * 2 --- sender has won the game
    //     * 3 --- sender has lost the game
    //     * 4 --- the game finished with draw
    //     * 5 --- sender is not a participant of the game
    function gameStatus() public constant returns (uint8) {
        // FIRST_PLAYER_WON, SECOND_PLAYER_WON, DRAW
        address sender = msg.sender;
        if (sender != firstPlayer_ && sender != secondPlayer_) {
            return 5;
        } else if (gameStatus_ == GameStatus.NOT_STARTED) {
            return 0;
        } else if (gameStatus_ == GameStatus.IN_PROGRESS) {
            return 1;
        } else if (
                (sender == firstPlayer_  && gameStatus_ == GameStatus.FIRST_PLAYER_WON) ||
                (sender == secondPlayer_ && gameStatus_ == GameStatus.SECOND_PLAYER_WON)) {
            return 2;
        } else if (
                (sender == firstPlayer_  && gameStatus_ == GameStatus.SECOND_PLAYER_WON) ||
                (sender == secondPlayer_ && gameStatus_ == GameStatus.FIRST_PLAYER_WON)) {
            return 3;
        } else if (gameStatus_ == GameStatus.DRAW) {
            return 4;
        }
    }

    // --------------------- modifiers

    modifier isSendersTurn() {
        require(gameStatus_ == GameStatus.IN_PROGRESS);
        require(
            (nextTurnPlayer_ == Player.FIRST  && msg.sender == firstPlayer_) ||
            (nextTurnPlayer_ == Player.SECOND && msg.sender == secondPlayer_)
        );
        _;
    }

    // --------------------------- internal functions

    function isFinished() internal constant returns(bool) {
        return (gameStatus_ == GameStatus.FIRST_PLAYER_WON)  ||
               (gameStatus_ == GameStatus.SECOND_PLAYER_WON) ||
               (gameStatus_ == GameStatus.DRAW);
    }

    function doMakeMove(Move move) internal {
        // TODO: убедиться в том, что я не перепутал строку и столбец
        require(board_[move.row][move.column] == Cell.EMPTY);
        if (nextTurnPlayer_ == Player.FIRST) {
            board_[move.row][move.column] = Cell.OCCUPIED_BY_FIRST_PLAYER;
        } else {
            board_[move.row][move.column] = Cell.OCCUPIED_BY_SECOND_PLAYER;
        }
        switchNextTurnPlayer();
        lastTurnNumber_++;
    }

    function switchNextTurnPlayer() internal {
        if (nextTurnPlayer_ == Player.FIRST) {
            nextTurnPlayer_ = Player.SECOND;
        } else {
            nextTurnPlayer_ = Player.FIRST;
        }
    }
}