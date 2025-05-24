// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract ScooterRaces {
    uint256 public raceIdCounter;
    uint256 public constant MAX_PLAYERS = 4;
    uint256 public constant TRACK_LENGTH = 100;

    enum RaceStatus { Waiting, Started, Finished }

    struct Player {
        address addr;
        uint256 distance;
        bool hasMoved;
    }

    struct Race {
        uint256 id;
        RaceStatus status;
        address[] players;
        mapping(address => Player) playerData;
        address winner;
        uint256 turn;
    }

    mapping(uint256 => Race) public races;

    event RaceCreated(uint256 raceId);
    event PlayerJoined(uint256 raceId, address player);
    event RaceStarted(uint256 raceId);
    event PlayerMoved(uint256 raceId, address player, uint256 distance);
    event RaceFinished(uint256 raceId, address winner);

    modifier onlyInRace(uint256 _raceId) {
        require(isPlayerInRace(_raceId, msg.sender), "Not a participant");
        _;
    }

    function createRace() external returns (uint256) {
        raceIdCounter++;
        uint256 newRaceId = raceIdCounter;

        Race storage r = races[newRaceId];
        r.id = newRaceId;
        r.status = RaceStatus.Waiting;

        emit RaceCreated(newRaceId);
        return newRaceId;
    }

    function joinRace(uint256 _raceId) external {
        Race storage r = races[_raceId];
        require(r.status == RaceStatus.Waiting, "Race not joinable");
        require(!isPlayerInRace(_raceId, msg.sender), "Already joined");
        require(r.players.length < MAX_PLAYERS, "Race full");

        r.players.push(msg.sender);
        r.playerData[msg.sender] = Player(msg.sender, 0, false);

        emit PlayerJoined(_raceId, msg.sender);

        if (r.players.length == MAX_PLAYERS) {
            r.status = RaceStatus.Started;
            r.turn = 1;
            emit RaceStarted(_raceId);
        }
    }

    function move(uint256 _raceId) external onlyInRace(_raceId) {
        Race storage r = races[_raceId];
        require(r.status == RaceStatus.Started, "Race not started");
        Player storage p = r.playerData[msg.sender];
        require(!p.hasMoved, "Already moved this turn");

        uint256 moveDistance = random(msg.sender) % 10 + 1; // 1–10 units per turn
        p.distance += moveDistance;
        p.hasMoved = true;

        emit PlayerMoved(_raceId, msg.sender, moveDistance);

        if (p.distance >= TRACK_LENGTH) {
            r.status = RaceStatus.Finished;
            r.winner = msg.sender;
            emit RaceFinished(_raceId, msg.sender);
        }

        if (allPlayersMoved(_raceId)) {
            resetTurn(_raceId);
            r.turn++;
        }
    }

    function isPlayerInRace(uint256 _raceId, address _player) public view returns (bool) {
        Race storage r = races[_raceId];
        for (uint i = 0; i < r.players.length; i++) {
            if (r.players[i] == _player) return true;
        }
        return false;
    }

    function allPlayersMoved(uint256 _raceId) internal view returns (bool) {
        Race storage r = races[_raceId];
        for (uint i = 0; i < r.players.length; i++) {
            if (!r.playerData[r.players[i]].hasMoved) return false;
        }
        return true;
    }

    function resetTurn(uint256 _raceId) internal {
        Race storage r = races[_raceId];
        for (uint i = 0; i < r.players.length; i++) {
            r.playerData[r.players[i]].hasMoved = false;
        }
    }

    function getPlayerProgress(uint256 _raceId, address _player) external view returns (uint256) {
        return races[_raceId].playerData[_player].distance;
    }

    function random(address _addr) internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, _addr, blockhash(block.number - 1))));
    }
}
