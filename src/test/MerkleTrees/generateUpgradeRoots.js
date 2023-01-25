const { MerkleTree } = require('merkletreejs')
const keccak256 = require('keccak256')
const { soliditySha3 } = require("web3-utils");

const fs = require('fs');
// const rawLeaves = [[1,1], [1,2], [1,3], [2,3]];
const rawLeaves = [[1,1]];


const buf2hex = x => '0x'+x.toString('hex');

const leaves = rawLeaves.map(v => soliditySha3(v[0], v[1]));

const tree = new MerkleTree(leaves, keccak256, { sort: true });
const root = tree.getRoot();
const hexroot = buf2hex(root);
console.log('root = ', hexroot);
//tree.print()

let finalProofs = {"root":hexroot, "upgrades": {}};
let maxVersion = 0;
for (leaveId in rawLeaves) {
    maxVersion = Math.max(rawLeaves[leaveId][0], rawLeaves[leaveId][1], maxVersion);
    finalProofs["upgrades"][`${rawLeaves[leaveId][0]} to ${rawLeaves[leaveId][1]}`] = {"proofs": tree.getProof(leaves[leaveId]).map(x => buf2hex(x.data))}
}

const data = JSON.stringify(finalProofs, null, 4);

fs.writeFileSync(`merkleTree_1to${maxVersion}.json`, data); //

console.log(finalProofs)
