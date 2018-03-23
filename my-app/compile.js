const path = require("path");
const fs = require("fs");
const solc = require("solc");

const Path = path.resolve(__dirname, "contracts", "baliv.sol");
const source = fs.readFileSync(Path, "utf8");
const PathAuth = path.resolve(__dirname, "contracts", "Authorization.sol");
const sourceAuth = fs.readFileSync(PathAuth, "utf8");
const PathMath = path.resolve(__dirname, "contracts", "SafeMath.sol");
const sourceMath = fs.readFileSync(PathMath, "utf8");
// console.log(Path)
// console.log(source)
// console.log(PathAuth)
// console.log(sourceAuth)
// console.log(PathMath)
// console.log(sourceMath)



var input = {
  'Authorization.sol': sourceAuth,
  'SafeMath.sol': sourceMath,
  'baliv.sol': source
}



// console.log(solc.compile({sources: input}, 1))
module.exports = solc.compile({sources: input}, 1)
// console.log(solc.compile(source, 1));
// module.exports = solc.compile(source, 1).contracts[':Baliv']
