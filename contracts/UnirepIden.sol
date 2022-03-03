pragma solidity ^0.8.0;

interface Unirep {
  function spendReputationViaRelayer(
    address attester,
    bytes memory signature,
    uint256 epochKey,
    uint256[] memory _nullifiers,
    ReputationProofSignals memory _proofSignals,
    uint256[8] memory _proof,
    uint256 spendReputationAmount
  ) external payable;

  struct Attestation {
    // The attester’s ID
    uint256 attesterId;
    // Positive reputation
    uint256 posRep;
    // Negative reputation
    uint256 negRep;
    // A hash of an arbitary string
    uint256 graffiti;
    // Whether or not to overwrite the graffiti in the user’s state
    bool overwriteGraffiti;
  }
}

// Start with a secret. Recursively hash 2**N times. Final hash is the genesis.
// Reveal the hashes in reverse order to prove identity.
// Extend proof by revealing one or more previous hashes
contract UnirepIden {
  // A user is represented by a uint256
  // Epoch key to a sha256 hash of a secret
  // A user will prove that they were a certain epoch key after the state
  // transition
  mapping (uint256 => bytes32) genesisHash;
  mapping (uint256 => bytes32) latestHash;

  // the unirep contract
  address immutable _u;

  address operator;
  uint public currentEpochKey = 0;

  constructor(address unirep, address _operator) {
    operator = _operator;
    _u = unirep;
    Unirep(_u).attesterSignUp();
  }

  function setCurrentEpochKey(uint key) public {
    require(msg.sender == operator);
    currentEpochKey = key;
  }

  // put the public key in a public place like an http server, then people can
  // attest to it
  function setGenesisHash(
    bytes32 genesisHash,
    Unirep.Attestation memory attestation,
    uint256 toEpochKey,
    uint256 fromEpochKey,
    uint256[] memory _nullifiers,
    Unirep.ReputationProofSignals memory _proofSignals,
    uint256[8] memory _proof
  ) public {
    require(attestation.negRep == 0, "Unirep Iden: should only be positive value");
    require(attestation.posRep >= 1, "Unirep Iden: should be at least 1");
    require(toEpochKey == currentEpochKey);

    // Spend attester's reputation
    // Call Unirep contract to perform reputation spending
    Unirep(_u).submitAttestation{value: unirep.attestingFee()}(
      attestation,
      fromEpochKey,
      toEpochKey,
      _nullifiers,
      _proofSignals,
      _proof
    );

    genesisHash[fromEpochKey] = genesisHash;
    // TODO: emit event
  }

  // oldest to newest
  // ideally do this with a zk proof lol
  function incrementProof(uint256 owner, bytes32[] proofChain) public {
    require(proofChain.length < type(uint16).max);
    require(proofChain.length >= 1);
    for (uint16 x = 0; x < proofChain.length; x++) {
      if (x == 0) {
        require(sha256(proofChain[x]) == latestHash[owner]);
      } else {
        require(sha256(proofChain[x]) == proofChain[x]);
      }
    }
    latestHash[owner] = proofChain[proofChain.length - 1];
    // TODO: emit event
  }
}
