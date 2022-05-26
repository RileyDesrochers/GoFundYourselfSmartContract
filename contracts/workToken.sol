//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
//import "github.com/Arachnid/solidity-stringutils/strings.sol";

struct ProjectCreater { 
   uint256 totalJobCost;
   uint16 jobs;
   uint256 jobTimeLimit;
   uint256[] jobsIssued;//?
   string tokenURI;
   uint16 jobsCompleted;
}

contract workToken is ERC721URIStorage{
    uint256 public startTotalJobCost;
    uint16 public jobLimit;
    uint256 public tokenCounter;
    IERC20 public stableCoin;
    enum tokenStatus{unFulfilled, fulfilled, expired}

    mapping(uint256 => tokenStatus) public tokenIdToStatus;
    mapping(uint256 => address) public tokenIdToProjectCreater;
    mapping(uint256 => uint256) public tokenIdToIssueTime;

    mapping(address => ProjectCreater) public ProjectCreaters;

    constructor() ERC721("WorkToken","WRK"){
        tokenCounter = 0;
        startTotalJobCost = 55;
        jobLimit = 10;
        //stableCoin = IERC20(_stableCoinAddress);
    }

    function approveFunds() public {
        stableCoin.approve(msg.sender, 1 * 10 ** 15);
    }
    
    function mintNFT(address ProjectCreaterAddress) public returns (uint256){ // make payable, fix uri
        tokenCounter++;
        tokenIdToStatus[tokenCounter] = tokenStatus(0);
        tokenIdToProjectCreater[tokenCounter] = ProjectCreaterAddress;
        tokenIdToIssueTime[tokenCounter] = block.timestamp;

        ProjectCreaters[ProjectCreaterAddress].jobsIssued.push(tokenCounter);

        uint256 jobCost = ProjectCreaters[ProjectCreaterAddress].totalJobCost / ProjectCreaters[ProjectCreaterAddress].jobs;

        //require(stableCoin.balanceOf(msg.sender) > jobCost);
        stableCoin.transferFrom(msg.sender, ProjectCreaterAddress, jobCost * 10 ** 6);// is this even safe?

        //transfer payment

        _safeMint(msg.sender, tokenCounter);
        _setTokenURI(tokenCounter, ProjectCreaters[ProjectCreaterAddress].tokenURI);
        return tokenCounter;
    }

    function newProjectCreater(uint16 jobs, uint256 jobTimeLimit, string memory tokenURI) public {
        require(ProjectCreaters[msg.sender].totalJobCost == 0);
        ProjectCreaters[msg.sender].totalJobCost = startTotalJobCost;
        projectCreaterChangeJob(jobs, jobTimeLimit, tokenURI);
    }

    function projectCreaterChangeJob(uint16 jobs, uint256 jobTimeLimit, string memory tokenURI) public {
        require(jobs <= jobLimit && jobs > 0);
        require(ProjectCreaters[msg.sender].totalJobCost != 0);
        ProjectCreaters[msg.sender].jobs = jobs;
        ProjectCreaters[msg.sender].jobTimeLimit = jobTimeLimit;
        ProjectCreaters[msg.sender].tokenURI = tokenURI;
        ProjectCreaters[msg.sender].jobsCompleted = 0;
    }

    function getProjectCreater(address projectCreater) public view returns (ProjectCreater memory) {
        return ProjectCreaters[projectCreater];
    }

    function compleateJob(uint256 jobIndex) public { // add modifyer, will inc for compleating out of date job
        address projectCreater = tokenIdToProjectCreater[jobIndex];
        //string memory tmp = ProjectCreaters[projectCreater].tokenURI;
        require(keccak256(abi.encodePacked(ProjectCreaters[projectCreater].tokenURI)) == keccak256(abi.encodePacked(tokenURI(jobIndex))));
        //require(StringUtils.equal(tmp, tokenURI(jobIndex)));
        
        tokenIdToStatus[jobIndex] = tokenStatus(1);//fix?
        ProjectCreaters[projectCreater].jobsCompleted++;

    }
    
    /*
    function upgradeIssuer() public {
        if(ProjectCreaters[projectCreater].jobsCompleted){

        }
    }
    */
    //function expireJob just del?
}
