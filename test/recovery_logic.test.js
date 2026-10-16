const { test, describe } = require('node:test');
const assert = require('node:assert');

class RecoveryMock {
  constructor(guardians, threshold, timelock) {
    this.guardians = new Set(guardians);
    this.threshold = threshold;
    this.timelock = timelock;
    this.requests = [];
  }

  initiateRecovery(guardian, proposedOwner, now) {
    if (!this.guardians.has(guardian)) throw new Error('Not guardian');
    const id = this.requests.length;
    this.requests.push({
      proposedOwner,
      approvals: new Set([guardian]),
      executionTime: now + this.timelock,
      executed: false,
      canceled: false,
    });
    return id;
  }

  vote(guardian, id) {
    if (!this.guardians.has(guardian)) throw new Error('Not guardian');
    const req = this.requests[id];
    if (req.approvals.has(guardian)) throw new Error('Already voted');
    req.approvals.add(guardian);
  }

  execute(id, now) {
    const req = this.requests[id];
    if (req.canceled) throw new Error('Canceled');
    if (req.approvals.size < this.threshold) throw new Error('Threshold not reached');
    if (now < req.executionTime) throw new Error('Timelock not elapsed');
    req.executed = true;
    return req.proposedOwner;
  }

  cancel(id) {
    const req = this.requests[id];
    if (req.executed) throw new Error('Already executed');
    req.canceled = true;
  }
}

describe('Social Recovery Guard Module Logic', () => {
  const g1 = '0x1111111111111111111111111111111111111111';
  const g2 = '0x2222222222222222222222222222222222222222';
  const g3 = '0x3333333333333333333333333333333333333333';
  const newOwner = '0x9999999999999999999999999999999999999999';

  test('successfully executes when threshold met and timelock passed', () => {
    const guard = new RecoveryMock([g1, g2, g3], 2, 86400); // 2 of 3, 24h timelock
    const now = 1000000;
    const id = guard.initiateRecovery(g1, newOwner, now);

    assert.throws(() => guard.execute(id, now + 86400 + 1), /Threshold not reached/);

    guard.vote(g2, id); // Reach 2 votes

    assert.throws(() => guard.execute(id, now + 1000), /Timelock not elapsed/);

    const winner = guard.execute(id, now + 86400 + 1);
    assert.strictEqual(winner, newOwner);
  });

  test('owner can cancel malicious recovery before timelock expiry', () => {
    const guard = new RecoveryMock([g1, g2, g3], 2, 86400);
    const now = 1000000;
    const id = guard.initiateRecovery(g1, newOwner, now);
    guard.vote(g2, id);

    guard.cancel(id);

    assert.throws(() => guard.execute(id, now + 86400 + 10), /Canceled/);
  });
});
