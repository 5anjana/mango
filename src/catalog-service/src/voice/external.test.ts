import test from 'node:test';
import assert from 'node:assert/strict';
import {
  catalogMetaYear,
  couchFacingLibraryStatus,
  deriveLibraryVerifyState,
  shouldRequeueFailedExactMatch,
} from './external.js';

test('deriveLibraryVerifyState marks verified titles in_library and not queued', () => {
  assert.deepEqual(deriveLibraryVerifyState('verified'), { inLibrary: true, alreadyQueued: false });
});

test('deriveLibraryVerifyState surfaces an already-pending title as queued_for_verify', () => {
  assert.deepEqual(deriveLibraryVerifyState('pending'), { inLibrary: false, alreadyQueued: true });
});

test('deriveLibraryVerifyState treats failed, stale, and absent titles as neither in_library nor queued', () => {
  assert.deepEqual(deriveLibraryVerifyState('failed'), { inLibrary: false, alreadyQueued: false });
  assert.deepEqual(deriveLibraryVerifyState('stale'), { inLibrary: false, alreadyQueued: false });
  assert.deepEqual(deriveLibraryVerifyState(undefined), { inLibrary: false, alreadyQueued: false });
});

test('couchFacingLibraryStatus never exposes failed or stale to the companion', () => {
  assert.equal(couchFacingLibraryStatus('verified'), 'verified');
  assert.equal(couchFacingLibraryStatus('pending'), 'pending');
  assert.equal(couchFacingLibraryStatus('failed'), undefined);
  assert.equal(couchFacingLibraryStatus('stale'), undefined);
  assert.equal(couchFacingLibraryStatus(undefined), undefined);
});

test('catalogMetaYear reads Cinemeta releaseInfo when year is absent', () => {
  assert.equal(catalogMetaYear({ releaseInfo: '2025' }), '2025');
  assert.equal(catalogMetaYear({ year: 1993 }), '1993');
  assert.equal(catalogMetaYear({ released: '1993-08-04' }), '1993');
  assert.equal(catalogMetaYear({ name: 'The Wedding Banquet' }), undefined);
});

test('shouldRequeueFailedExactMatch only for exact-score tombstones', () => {
  assert.equal(shouldRequeueFailedExactMatch('failed', 100), true);
  assert.equal(shouldRequeueFailedExactMatch('stale', 100), true);
  assert.equal(shouldRequeueFailedExactMatch('failed', 92), false);
  assert.equal(shouldRequeueFailedExactMatch('verified', 100), false);
  assert.equal(shouldRequeueFailedExactMatch('pending', 100), false);
  assert.equal(shouldRequeueFailedExactMatch(undefined, 100), false);
});
