#! /usr/bin/env python3.5

class Repl:

    def __init__(self) -> None:
        position_format_description = 'The position is specified as <COLUMN><LINE>, e.g. H8.'
        self._commands = {
            # command -> (handler_function, arguments_description, help description)
            'create game': (
                self._on_create_game,
                '',
                'create a new game and get its address to share with a friend.'
            ),
            'join game': (
                self._on_join_hame,
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
                '<MOVE>'
                'make the fifth move from. Note that the MOVE should be one of the suggested ones.'
            ),  # one of the suggested fifth move options
            'pass': (
                self._on_pass,
                '',
                'pass the turn.'
            ),
            'refresh': (
                self._on_refresh,
                ''
                'load the actual state from the blockchain and print it out.'
            ),  # update the state and print it
            'help': (
                self._on_help,
                '',
                'print all available commands'
            )
        }

    def handle_user_input(self, line: str):
        line = line.strip()
        for command, (handler, _, _) in self._commands.items():
            if line.startswith(command):
                args = line[len(command):].strip()
                return handler(args)
        print("Invalid command.")
        self._on_help('')

    def _on_create_game(self, _: str):
        pass

    def _on_join_hame(self, game_address: str):
        pass

    def _on_resume_game(self, game_address: str):
        pass

    def _on_move(self, move: str):
        pass

    def _on_pick_color(self, color: str):
        pass

    def _on_suggest(self, options: str):
        pass

    def _on_select(self, move: str):
        pass

    def _on_pass(self, _: str):
        pass

    def _on_refresh(self, _: str):
        pass

    def _on_help(self, _: str):
        print("The following commands are available:")
        for command, (_, args, description) in self._commands.items():
            print("  * {} {}  -- {}".format(command, args, description))

    def _parse_move(self, move: str) -> (int, int):
        if len(str) != 2:
            raise ValueError("Invalid")