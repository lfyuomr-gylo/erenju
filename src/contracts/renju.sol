pragma solidity ^0.4.0;

// TODO: check the moves are not disallowed
// TODO: forbid to join the game without paying enough money
// TODO: добавить завершение игры ничьёй, если сделано два паса подряд
// TODO: добавить послеходовую проверку на то, что игра закончилась чьей-то победой.

contract Renju {

    enum Player { BLACK, WHITE }

    struct Move {
        int8 row;
        int8 column;
    }

    struct FifthMoveProposal {
        // indicates whether this structure instance contains user-provided data
        // or is initialized with zero bytes by default
        bool isProvided;

        bool isSelected;
        Move[2] options;
    }

    enum Cell { EMPTY, BLACK, WHITE }

    enum GameStatus { NOT_STARTED, IN_PROGRESS, FIRST_PLAYER_WON, SECOND_PLAYER_WON, DRAW }

    // ----------------- end of enum/struct declarations

    address blackPlayer_;

    address whitePlayer_;

    // the 1-based index of the last performed turn. The first turn is performed at the contract creation
    uint8 public lastTurnNumber_ = 1;

    // indicates which player has to perform the next action in the game.
    // The action could be a move, a pass or some special activity in the
    // opening(like color selection).
    //
    // the very first move is performed implicitly by the first player at the moment
    // of the contract creation
    Player nextTurnPlayer_ = Player.WHITE;

    bool isColorPickFinished_ = false;

    FifthMoveProposal fifthMoveProposal_;

    GameStatus gameStatus_ = GameStatus.NOT_STARTED;

    Cell[15][15] board_;

    // ------------------ end of field declarations

    // fuck you guys who decided that to use the contract name for constructor declaration is a good idea in 2014...
    function Renju() public {
        // initially we assume that
        blackPlayer_ = msg.sender;
        for (uint8 i = 0; i < 15; i++) {
            for (uint8 j = 0; j < 15; j++) {
                board_[i][j] = Cell.EMPTY;
            }
        }
        board_[7][7] = Cell.BLACK; // make the very first move
    }

    // ------------ actions

    function joinTheGame() public {
        require(gameStatus_ == GameStatus.NOT_STARTED);
        require(msg.sender != blackPlayer_);

        whitePlayer_ = msg.sender;
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

    function pickColor(bool blackColorIsChosen) public isSendersTurn() {
        require(lastTurnNumber_ == 3);

        assert(nextTurnPlayer_ == Player.WHITE);
        if (blackColorIsChosen) {
            address tmp = blackPlayer_;
            blackPlayer_ = whitePlayer_;
            whitePlayer_ = tmp;
        }
        isColorPickFinished_ = true;
        // the next action is performed by white player, so no need to switch turn
    }

    function suggestFifthMove(uint8 line1, uint8 column1, uint8 line2, uint8 column2) public isSendersTurn() {
        require(lastTurnNumber_ == 4);
        require(!fifthMoveProposal_.isProvided);

        fifthMoveProposal_.isProvided = true;
        fifthMoveProposal_.isSelected = false;
        fifthMoveProposal_.options[0] = requireMoveIsPossible(Move(line1, column1));
        fifthMoveProposal_.options[1] = requireMoveIsPossible(Move(line2, column2));

        switchNextTurnPlayer();
    }

    function selectFifthMove(uint8 row, uint8 column) public isSendersTurn() {
        require(lastTurnNumber_ == 4);
        require(fifthMoveProposal_.isProvided && !fifthMoveProposal_.isSelected);

        Move proposedMove = requireIsProposedForFifthMove(row, column);
        fifthMoveProposal_.isSelected = true;
        doMakeMove(proposedMove);
    }

    function pass() public isSendersTurn() {
        require(lastTurnNumber_ >= 6);
        switchNextTurnPlayer();
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
        if (sender != blackPlayer_ && sender != whitePlayer_) {
            return 5;
        } else if (gameStatus_ == GameStatus.NOT_STARTED) {
            return 0;
        } else if (gameStatus_ == GameStatus.IN_PROGRESS) {
            return 1;
        } else if (
                (sender == blackPlayer_  && gameStatus_ == GameStatus.FIRST_PLAYER_WON) ||
                (sender == whitePlayer_ && gameStatus_ == GameStatus.SECOND_PLAYER_WON)) {
            return 2;
        } else if (
                (sender == blackPlayer_  && gameStatus_ == GameStatus.SECOND_PLAYER_WON) ||
                (sender == whitePlayer_ && gameStatus_ == GameStatus.FIRST_PLAYER_WON)) {
            return 3;
        } else if (gameStatus_ == GameStatus.DRAW) {
            return 4;
        }
    }

    // --------------------- modifiers

    modifier isSendersTurn() {
        require(gameStatus_ == GameStatus.IN_PROGRESS);
        require(
            (nextTurnPlayer_ == Player.BLACK  && msg.sender == blackPlayer_) ||
            (nextTurnPlayer_ == Player.WHITE && msg.sender == whitePlayer_)
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
        if (nextTurnPlayer_ == Player.BLACK) {
            board_[move.row][move.column] = Cell.BLACK;
        } else {
            board_[move.row][move.column] = Cell.WHITE;
        }
        switchNextTurnPlayer();
        lastTurnNumber_++;
    }

    function requireMoveIsPossible(Move move) internal returns(Move) {
        require(board_[move.row][move.column] == Cell.EMPTY);
        return move;
    }

    function requireIsProposedForFifthMove(uint8 row, uint8 column) internal pure returns(Move) {
        require(
            (row == fifthMoveProposal_.options[0].row && column == fifthMoveProposal_.options[0].column) ||
            (row == fifthMoveProposal_.options[1].row && column == fifthMoveProposal_.options[1].column)
        );
        return Move(row, column);
    }

    function switchNextTurnPlayer() internal {
        if (nextTurnPlayer_ == Player.BLACK) {
            nextTurnPlayer_ = Player.WHITE;
        } else {
            nextTurnPlayer_ = Player.BLACK;
        }
    }
}