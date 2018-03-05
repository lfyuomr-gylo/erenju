import time
from solc import compile_source
from web3 import Web3, HTTPProvider
from web3.contract import ConciseContract

class Interceptor:
    def __init__(self, contract, user_address) -> None:
        self.run_in_transaction = True
        self._contract = contract
        self._user_address = user_address

    def __getattr__(self, name: str):
        attr = self._contract.__getattr__(name)
        if hasattr(attr, '__call__'):
            mode = 'transact' if self.run_in_transaction else 'call'
            my_kwarg = {mode: {'from': self._user_address}}
            return lambda *args, **kwargs: attr(*args, **my_kwarg)
        return attr

    def call(self):
        self.run_in_transaction = False
        return self

    def transact(self):
        self.run_in_transaction = True
        return self

class EthereumClient:
    def __init__(self, ethereum_url, user_address) -> None:
        self.contract_interface = self._load_contract_interface()
        self.w3 = Web3(HTTPProvider(ethereum_url))
        self.user_address = user_address

    def upload_new_erenju_contract(self) -> (str, ConciseContract):
        contract = self.w3.eth.contract(abi=self.contract_interface['abi'], bytecode=self.contract_interface['bin'])
        # TODO: support user authentication
        tx_hash = contract.deploy(transaction={'from': self.user_address, 'gas': 4100000})
        tx_receipt = self._tx_receipt(tx_hash)
        contract_address = tx_receipt['contractAddress']
        contract_instance = self.w3.eth.contract(
            self.contract_interface['abi'],
            contract_address,
            ContractFactoryClass=ConciseContract
        )
        return contract_address, self._wrap_contract(contract_instance)

    def contract_by_address(self, contract_address: str) -> ConciseContract:
        contract_instance =  self.w3.eth.contract(
            self.contract_interface['abi'],
            contract_address,
            ContractFactoryClass=ConciseContract
        )
        return self._wrap_contract(contract_instance)

    def _load_contract_interface(self):
        contract_source_code = ''
        with open("erenju/contracts/Renju.sol") as f:
            contract_source_code = f.read()
        compiled_sol = compile_source(contract_source_code)
        return compiled_sol['<stdin>:Renju']

    def _wrap_contract(self, contract):
        return Interceptor(contract, self.user_address)

    def _tx_receipt(self, tx_hash):
        tx_receipt = None
        while tx_receipt is None:
            time.sleep(1)
            tx_receipt = self.w3.eth.getTransactionReceipt(tx_hash)
        return tx_receipt