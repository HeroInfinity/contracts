const { time } = require("@openzeppelin/test-helpers");

const MINDELAY = time.duration.hours(2).toString(); // 2 hours

module.exports = {
  MINDELAY,
};
