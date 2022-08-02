/// @dev The Fuel testing setup.
/// A set of useful helper methods for setting up the integration test environment.
import axios from 'axios';
import { ethers, Signer as EthSigner } from 'ethers';
import { Provider as EthProvider } from '@ethersproject/providers';
import { Provider as FuelProvider } from '@fuel-ts/providers';
import { Wallet as FuelWallet } from '@fuel-ts/wallet';
import { fuels_parseEther, fuels_formatEther } from '../scripts/utils';
import { FuelMessageInbox } from '../fuel-v2-contracts-typechain/FuelMessageInbox.d';
import { FuelMessageInbox__factory } from '../fuel-v2-contracts-typechain/factories/FuelMessageInbox__factory';
import { FuelMessageOutbox } from '../fuel-v2-contracts-typechain/FuelMessageOutbox.d';
import { FuelMessageOutbox__factory } from '../fuel-v2-contracts-typechain/factories/FuelMessageOutbox__factory';
import { L1ERC20Gateway } from '../fuel-v2-contracts-typechain/L1ERC20Gateway.d';
import { L1ERC20Gateway__factory } from '../fuel-v2-contracts-typechain/factories/L1ERC20Gateway__factory';

// Setup options
export interface SetupOptions {
	http_ethereum_client?: string;
	http_deployer?: string;
	http_fuel_client?: string;
	pk_eth_deployer?: string;
	pk_eth_signer1?: string;
	pk_eth_signer2?: string;
	pk_fuel_deployer?: string;
	pk_fuel_signer1?: string;
	pk_fuel_signer2?: string;
}

// The test environment
export interface TestEnvironment {
	eth: {
		provider: EthProvider;
		fuelMessageInbox: FuelMessageInbox;
		fuelMessageOutbox: FuelMessageOutbox;
		l1ERC20Gateway: L1ERC20Gateway;
		deployer: EthSigner;
		signers: EthSigner[];
	},
	fuel: {
		provider: FuelProvider;
		deployer: FuelWallet;
		signers: FuelWallet[];
	}
}

// The setup method for Fuel
export async function setupEnvironment(opts: SetupOptions): Promise<TestEnvironment> {
	const http_ethereum_client: string = opts.http_ethereum_client || "http://127.0.0.1:9545";
	const http_deployer: string = opts.http_deployer || "http://127.0.0.1:8080";
	const http_fuel_client: string = opts.http_fuel_client || "http://127.0.0.1:4000";
	const pk_eth_deployer: string = opts.pk_eth_deployer || "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";
	const pk_eth_signer1: string = opts.pk_eth_signer1 || "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d";
	const pk_eth_signer2: string = opts.pk_eth_signer2 || "0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a";
	const pk_fuel_deployer: string = opts.pk_fuel_deployer || "0xa449b1ffee0e2205fa924c6740cc48b3b473aa28587df6dab12abc245d1f5298";
	const pk_fuel_signer1: string = opts.pk_fuel_signer1 || "0x6fbaf19e3e42af0becc628e954557a8616d702b0c7ce9f2dd2580a16bebe357a";
	const pk_fuel_signer2: string = opts.pk_fuel_signer2 || "0xd4de6ad33dae7d7987711360b8ff9298f1838c9542c6efafa0e8c74b11e5623d";

	// Create provider from http_fuel_client
    const fuel_provider = new FuelProvider(http_fuel_client + '/graphql');
	try {
		await fuel_provider.getBlockNumber();
	} catch(e) {
		throw new Error("Failed to connect to the Fuel client at (" + http_fuel_client + "). Are you sure it's running?");
	}
	const fuel_deployer = new FuelWallet(pk_fuel_deployer, fuel_provider);
	const fuel_deployerBalance = await fuel_deployer.getBalance();
	if(fuel_deployerBalance < fuels_parseEther("5")) {
		throw new Error("Fuel deployer balance is very low (" + fuels_formatEther(fuel_deployerBalance) + "ETH)");
	}
	const fuel_signer1 = new FuelWallet(pk_fuel_signer1, fuel_provider);
	const fuel_signer1Balance = await fuel_signer1.getBalance();
	if(fuel_signer1Balance < fuels_parseEther("1")) {
		const tx = await fuel_deployer.transfer(fuel_signer1.address, fuels_parseEther("1"));
		await tx.wait();
	}
	const fuel_signer2 = new FuelWallet(pk_fuel_signer2, fuel_provider);
	const fuel_signer2Balance = await fuel_signer2.getBalance();
	if(fuel_signer2Balance < fuels_parseEther("1")) {
		const tx = await fuel_deployer.transfer(fuel_signer2.address, fuels_parseEther("1"));
		await tx.wait();
	}

	// Create provider and signers from http_ethereum_client
	const eth_provider = new ethers.providers.JsonRpcProvider(http_ethereum_client);
	try {
		await eth_provider.getBlockNumber();
	} catch(e) {
		throw new Error("Failed to connect to the Ethereum client at (" + http_ethereum_client + "). Are you sure it's running?");
	}
	const eth_deployer = new ethers.Wallet(pk_eth_deployer, eth_provider);
	const eth_deployerBalance = await eth_deployer.getBalance();
	if(eth_deployerBalance.lt(ethers.utils.parseEther("5"))) {
		throw new Error("Ethereum deployer balance is very low (" + ethers.utils.formatEther(eth_deployerBalance) + "ETH)");
	}
	const eth_signer1 = new ethers.Wallet(pk_eth_signer1, eth_provider);
	const eth_signer1Balance = await eth_signer1.getBalance();
	if(eth_signer1Balance.lt(ethers.utils.parseEther("1"))) {
		const tx = await eth_deployer.sendTransaction({
			to: (await eth_signer1.getAddress()),
			value: ethers.utils.parseEther("1")
		});
		await tx.wait();
	}
	const eth_signer2 = new ethers.Wallet(pk_eth_signer2, eth_provider);
	const eth_signer2Balance = await eth_signer2.getBalance();
	if(eth_signer2Balance.lt(ethers.utils.parseEther("1"))) {
		const tx = await eth_deployer.sendTransaction({
			to: (await eth_signer2.getAddress()),
			value: ethers.utils.parseEther("1")
		});
		await tx.wait();
	}

	// Get contract addresses from http_deployer
	let deployerAddresses: any = null;
	try {
		deployerAddresses = (await axios.get(http_deployer + "/addresses.json")).data;
	} catch(e) {
		throw new Error("Failed to connect to the deployer at (" + http_deployer + "). Are you sure it's running?");
	}
	if(!deployerAddresses.FuelMessageOutbox) {
		throw new Error("Failed to get FuelMessageOutbox address from deployer");
	}
	const eth_fuelMessageOutboxAddress: string = deployerAddresses.FuelMessageOutbox;
	if(!deployerAddresses.FuelMessageInbox) {
		throw new Error("Failed to get FuelMessageInbox address from deployer");
	}
	const eth_fuelMessageInboxAddress: string = deployerAddresses.FuelMessageInbox;
	if(!deployerAddresses.L1ERC20Gateway) {
		throw new Error("Failed to get L1ERC20Gateway address from deployer");
	}
	const eth_l1ERC20GatewayAddress: string = deployerAddresses.L1ERC20Gateway;

	// Connect existing contracts
	let eth_fuelMessageInbox: FuelMessageInbox = FuelMessageInbox__factory.connect(eth_fuelMessageInboxAddress, eth_signer1);
	let eth_fuelMessageOutbox: FuelMessageOutbox = FuelMessageOutbox__factory.connect(eth_fuelMessageOutboxAddress, eth_signer1);
	let eth_l1ERC20Gateway: L1ERC20Gateway = L1ERC20Gateway__factory.connect(eth_l1ERC20GatewayAddress, eth_signer1);

	// Return the Fuel harness object
	return {
		eth: {
			provider: eth_provider,
			fuelMessageInbox: eth_fuelMessageInbox,
			fuelMessageOutbox: eth_fuelMessageOutbox,
			l1ERC20Gateway: eth_l1ERC20Gateway,
			deployer: eth_deployer,
			signers: [eth_signer1, eth_signer2]
		},
		fuel: {
			provider: fuel_provider,
			deployer: fuel_deployer,
			signers: [fuel_signer1, fuel_signer2]
		}
	};
}
