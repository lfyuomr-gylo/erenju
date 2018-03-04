#! /usr/bin/env python3.5

import argparse

import sys

from erenju.ethereum_client import EthereumClient
from erenju.repl import Repl

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("-e", "--ethereum-url", type=str, help="The url of the ethereum node to use.")
    parser.add_argument("-a", "--address", type=str, help="The ethereum address of the player.")
    args = parser.parse_args()

    eth_client = EthereumClient(args.ethereum_url, args.address)
    repl = Repl(eth_client)

    while True: # in debugger iteration over sys.stdin throws exception =(
        line = input()
    # for line in sys.stdin
        repl.handle_user_input(line)
