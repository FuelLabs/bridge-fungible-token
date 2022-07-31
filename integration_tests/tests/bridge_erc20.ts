import chai from 'chai';
import { solidity } from 'ethereum-waffle';
import { ethers } from 'ethers';
import { TestEnvironment, setupEnvironment } from '../scripts/setup';
import { Token } from '../fuel-v2-contracts-typechain/Token.d';
import { Token__factory } from '../fuel-v2-contracts-typechain/factories/Token__factory';

chai.use(solidity);
const { expect } = chai;

describe('Bridging ERC20 tokens', async () => {
	let env: TestEnvironment;
	let ethAccountAddress: string;
	let eth_testToken: Token;

	before(async () => {
		env = await setupEnvironment({});
		ethAccountAddress = await env.eth.signers[0].getAddress();
	});

	it('Setup tokens to bridge', async () => {
		// Create test ERC20 contract
		const eth_tokenFactory = new Token__factory(env.eth.deployer);
		eth_testToken = await eth_tokenFactory.deploy();
		await eth_testToken.deployed();

		// mint tokens for bridging
		await expect(eth_testToken.mint(ethAccountAddress, 1000)).to.not.be.reverted

		// approve l1 side gateway to spend the tokens
		await expect(eth_testToken.approve(env.eth.l1ERC20Gateway.address, 10_000)).to.not.be.reverted
	
		//TODO: setup fuel client and setup l2 side contract for ERC20
	});

	describe('Bridge ERC20 to Fuel', async () => {
		it('Bridge ERC20 via L1ERC20Gateway', async () => {
			//TODO
		});

		it('Relay Message from Ethereum on Fuel', async () => {
			//TODO
		});

		it('Check ERC20 arrived on Fuel', async () => {
			//TODO
		});
	});

	describe('Bridge ERC20 from Fuel', async () => {
		it('Bridge ERC20 via Fuel token contract', async () => {
			//TODO
		});

		it('Relay Message from Fuel on Ethereum', async () => {
			//TODO
		});

		it('Check ERC20 arrived on Ethereum', async () => {
			//TODO
		});
	});
});
