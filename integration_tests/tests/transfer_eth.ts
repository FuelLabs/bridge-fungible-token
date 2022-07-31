import chai from 'chai';
import { solidity } from 'ethereum-waffle';
import { ethers } from 'ethers';
import { TestEnvironment, setupEnvironment } from '../scripts/setup';

chai.use(solidity);
const { expect } = chai;

describe('Transferring ETH', async () => {
	let env: TestEnvironment;

	before(async () => {
		env = await setupEnvironment({});
	});

	describe('Send ETH to Fuel', async () => {
		it('Send ETH via MessageOutbox', async () => {
			//TODO: this recevier should come from the environment setup so we can then try to send the ETH back
			const fuelETHReceiver = "0xd4630940afb6f40f190c6204a44f94f9bb1eb104df4cf488cb6645a62f249186";

			// use the FuelMessageOutbox to directly send ETH which should be immediately spendable
			await expect(
				env.eth.fuelMessageOutbox.sendETH(fuelETHReceiver, {
					value: ethers.utils.parseEther("0.1")
				})
			).to.not.be.reverted;
		});

		it('Check ETH arrived on Fuel', async () => {
			//TODO
		});
	});

	describe('Send ETH from Fuel', async () => {
		it('Send ETH via OutputMessage', async () => {
			//TODO
		});

		it('Relay Message from Fuel on Ethereum', async () => {
			//TODO
		});

		it('Check ETH arrived on Ethereum', async () => {
			//TODO
		});
	});
});
