from erenju import ethereum_client


class Repl:

    def __init__(self, eth_client: ethereum_client) -> None:
        self._eth_client = eth_client
        self._contract = None

        # constants:
        position_format_description = 'The position is specified as <COLUMN><LINE>, e.g. H8.'
        self._commands = {
            # command -> (handler_function, arguments_description, help description)
            'create game': (
                self._on_create_game,
                '',
                'create a new game and get its address to share with a friend.'
            ),
            'join game': (
                self._on_join_game,
                '<GAME ADDRESS>',
                'join to an existing game at the specific address to start playing.'
            ),
            'resume game': (
                self._on_resume_game,
                '<GAME ADDRESS>',
                'connect to an existing game you are already participant of.'
            ),
            'move': (
                self._on_move,
                '<MOVE>',
                'put your stone to the specified position. ' + position_format_description
            ),
            'pick color': (
                self._on_pick_color,
                '<COLOR>',
                'perform color pick in the opening. Color is either BLACK or WHITE and is recognized case-insensitively.'
            ),
            'suggest': (
                self._on_suggest,
                '<MOVE1> <MOVE2>',
                'suggest the options of the fifth move positions in the opening. ' + position_format_description
            ),
            'select': (
                self._on_select,
                '<MOVE>',
                'make the fifth move from. Note that the MOVE should be one of the suggested ones.'
            ),  # one of the suggested fifth move options
            'pass': (
                self._on_pass,
                '',
                'pass the turn.'
            ),
            'refresh': (
                self._on_refresh,
                '',
                'load the actual state from the blockchain and print it out.'
            ),  # update the state and print it
            'help': (
                self._on_help,
                '',
                'print all available commands'
            )
        }
        self._column_letters = dict(zip((chr(c) for c in range(ord('A'), ord('O') + 1)), range(15)))

    def __getattribute__(self, name: str):
        attr = object.__getattribute__(self, name)
        if name == "_contract" and attr is None:
            raise ValueError("You are not connected to any game")
        return attr

    def handle_user_input(self, line: str):
        try:
            self._handle_user_input(line)
        except ValueError as e:
            print("Failed: {}".format(str(e)))

    def _handle_user_input(self, line: str):
        line = line.strip()
        for command, (handler, *_) in self._commands.items():
            if line.startswith(command):
                args = line[len(command):].strip()
                return handler(args)
        print("Invalid command.")
        self._on_help('')

    def _on_create_game(self, _: str):
        addr, contract = self._eth_client.upload_new_erenju_contract()
        print(("Successfully created a game at address {}. Now you can share this "
              "address with your friend to start playing with him.").format(addr))
        self._contract = contract

    def _on_join_game(self, game_address: str):
        self._contract = self._eth_client.contract_by_address(game_address)
        self._contract.transact().joinTheGame()
        print("Successfully joined to the game.")
        self._print_board()

    def _on_resume_game(self, game_address: str):
        self._contract = self._eth_client.contract_by_address(game_address)
        #  TODO: check that I'm participant
        print("Successfully connected to the game.")

    def _on_move(self, move: str):
        line, column = self._parse_move(move)
        self._contract.transact().makeMove(line, column)
        print("Done.")
        self._print_board()

    def _on_pick_color(self, color: str):
        color_is_black = None
        if color.upper() == "BLACK":
            color_is_black = True
        elif color.upper() == "WHITE":
            color_is_black = False
        else:
            raise ValueError("Malformed color {}", color)
        self._contract.transact().pickColor(color_is_black)
        print("Done.")

    def _on_suggest(self, options: str):
        (line1, column1), (line2, column2) = \
            map(self._parse_move, map(str.strip, options.split(' ')))
        self._contract.transact().suggestFifthMove(line1, column1, line2, column2)
        print("Done.")

    def _on_select(self, move: str):
        line, column = self._parse_move(move)
        self._contract.transact().selectFifthMove(line, column)
        print("Done.")
        self._print_board()

    def _on_pass(self, _: str):
        self._contract.transact().passTurn()

    def _on_refresh(self, _: str):
        self._print_board()

    def _on_help(self, _: str):
        print("The following commands are available:")
        for command, (_, args, description) in self._commands.items():
            print("  * {} {}  -- {}".format(command, args, description))

    def _parse_move(self, move: str) -> (int, int):
        if len(move) not in (2, 3) :
            raise ValueError("Invalid MOVE format. It should be 2- or 3-characters long")
        column = self._column_letters.get(move[0].upper(), None)
        if column is None:
            raise ValueError("Invalid MOVE format: unexpected column identifier: {}".format(move[0]))
        line = int(move[1:])
        if not 1 <= line <= 15:
            raise ValueError("Invalid MOVE format: unexpected line index {}. It is required to be in range [1, 15]")
        return (15 - line), column

    def _print_board(self):
        self._print_current_turn()
        print()
        print(" " * 3 + " ".join(sorted(self._column_letters.keys()))) # columns header
        for line in range(15, 0, -1):
            print(line, end=' ' if line >= 10 else '  ') # print two spaces to align the first column
            for column in range(15):
                cell_number = self._contract.call().cellAt(15 - line, column)
                cell_letter = None
                if cell_number == 0:
                    cell_letter = 'O'
                elif cell_number == 1:
                    cell_letter = 'B'
                elif cell_number == 2:
                    cell_letter = 'W'
                else:
                    raise ValueError("Unexpected cell value got from the contract: {}".format(cell_number))
                print(cell_letter, end=' ')
            print()

    def _print_current_turn(self):
        if self._print_if_game_finished_and_return_true():
            return
        current_turn = self._contract.call().currentTurn()
        if current_turn == 0:
            print("Game is not in progress")
        elif current_turn == 1:
            print("It's your turn to pick the color!")
        elif current_turn == 2:
            print("Waiting for the opponent to pick color")
        elif current_turn == 3:
            print("It's your turn to suggest options for fifth move")
        elif current_turn == 4:
            print("Waiting for the opponent to suggest the fifth move options")
        elif current_turn == 5:
            print("It's your turn to select the fifth move")
            line1, column1, line2, column2 = self._contract.call().fifthTurnSuggestion()
            move1 = self.move_str(line1, column1)
            move2 = self.move_str(line2, column2)
            print("Available moves: {} {}".format(move1, move2))
        elif current_turn == 6:
            print("Waiting for the opponent to select the fifth move")
        elif current_turn == 7:
            print("It's your turn to move!")
        elif current_turn == 8:
            print("Waiting for the opponent's move")
        else:
            raise ValueError("Unexpected return value of 'currentTurn' contract method: {}".format(current_turn))

    def _print_if_game_finished_and_return_true(self):
        game_status = self._contract.call().gameStatus()
        if game_status == 2:
            print("Congratulations! You have won!")
            return True
        elif game_status == 3:
            print("Unfortunately, you have lost. Try again!")
            return True
        elif game_status == 4:
            print("The game finished with draw. Try again.")
            return True
        else:
            return False

    def move_str(self, line, column):
        return chr(ord('A') + column) + str(15 - line)


if __name__ == "__main__":
    Repl(None).handle_user_input("suggest B8 B5")