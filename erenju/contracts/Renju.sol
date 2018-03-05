pragma solidity ^0.4.0;

// TODO: check the moves are not disallowed
// TODO: forbid to join the game without paying enough money
// TODO: добавить завершение игры ничьёй, если сделано два паса подряд
// TODO: добавить послеходовую проверку на то, что игра закончилась чьей-то победой.

contract Renju {

    enum Player { BLACK, WHITE }

    struct Move {
        uint8 row;
        uint8 column;
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
        Move memory move = Move(line, column);
        if (lastTurnNumber_ == 1) {
            require(6 <= move.row    && move.row    <= 8);
            require(6 <= move.column && move.column <= 8);
        }
        if (lastTurnNumber_ == 2) {
            require(5 <= move.row    && move.row    <= 9);
            require(5 <= move.column && move.column <= 9);
        }
        if (lastTurnNumber_ >= 3) {
            require(isColorPickFinished_);
        }
        require(lastTurnNumber_ != 4); // the fifth turn is performed via a separate function

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

        Move memory proposedMove = requireIsProposedForFifthMove(row, column);
        fifthMoveProposal_.isSelected = true;
        doMakeMove(proposedMove);
    }

    // do not name this method 'pass' since it's python keyword
    function passTurn() public isSendersTurn() {
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

    function cellAt(uint8 line, uint8 column) public constant returns (uint8) {
        Cell cell = board_[line][column];
        if (cell == Cell.EMPTY) {
            return 0;
        } else if (cell == Cell.BLACK) {
            return 1;
        } else if (cell == Cell.WHITE) {
            return 2;
        } else {
            assert(false);
        }
    }

    function currentTurn() public constant returns (uint8) {
        if (gameStatus_ != GameStatus.IN_PROGRESS) {
            return 0; // game is not in progress
        } else if (lastTurnNumber_ == 3 && !isColorPickFinished_) {
            if (isMyTurn()) {
                return 1; // waiting for your color pick
            } else {
                return 2; // waiting for opponents color pick
            }
        } else if (lastTurnNumber_ == 4 && !fifthMoveProposal_.isProvided) {
            if (isMyTurn()) {
                return 3; // waiting for your fifth turn proposal
            } else {
                return 4; // waiting for opponent's fifth turn proposal
            }
        } else if (lastTurnNumber_ == 4 && !fifthMoveProposal_.isSelected) {
            if (isMyTurn()) {
                return 5; // waiting for you to select fifth move
            } else {
                return 6; // waiting for opponent to select fifth move
            }
        } else if (isMyTurn()) {
            return 7; // waiting for your regular turn
        } else {
            return 8; // waiting for opponent's regular turn.
        }
    }

    function fifthTurnSuggestion() public constant returns (uint8[4]) {
        return [
            fifthMoveProposal_.options[0].row,
            fifthMoveProposal_.options[0].column,
            fifthMoveProposal_.options[1].row,
            fifthMoveProposal_.options[1].column
        ];
    }

    function isMyTurn() public constant returns (bool) {
        return (gameStatus_ == GameStatus.IN_PROGRESS) && (
            (nextTurnPlayer_ == Player.BLACK  && msg.sender == blackPlayer_) ||
            (nextTurnPlayer_ == Player.WHITE &&  msg.sender == whitePlayer_)
        );
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

    function requireMoveIsPossible(Move move) internal view returns(Move) {
        require(board_[move.row][move.column] == Cell.EMPTY);
        return move;
    }

    function requireIsProposedForFifthMove(uint8 row, uint8 column) internal view returns(Move) {
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