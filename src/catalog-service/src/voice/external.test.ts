import test from 'node:test';
import assert from 'node:assert/strict';
import {
  catalogMetaYear,
  couchFacingLibraryStatus,
  deriveLibraryVerifyState,
  rankExternalHits,
  shouldRequeueFailedExactMatch,
} from './external.js';
import type { ExternalSearchHit } from './external.js';

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

test('rankExternalHits keeps the catalog order among equal scores instead of sorting by title', () => {
  const hit = (id: string, title: string, year: string, score = 100): ExternalSearchHit => ({
    type: 'movie',
    id,
    title,
    year,
    tab: 'movies',
    score,
    in_library: false,
    library_status: undefined,
    queued_for_verify: false,
  });
  // Cinemeta returns the popular "Emma." (2020) first; its period sorted it
  // last alphabetically and the result cap dropped it.
  const ranked = rankExternalHits([
    hit('tt9214832', 'Emma.', '2020'),
    hit('tt0116191', 'Emma', '1996'),
    hit('tt0118308', 'Emma', '1996'),
    hit('tt0022854', 'Emma', '1932', 92),
  ]);
  assert.deepEqual(ranked.map((item) => item.id), ['tt9214832', 'tt0116191', 'tt0118308', 'tt0022854']);
  const inLibrary = rankExternalHits([
    hit('tt9214832', 'Emma.', '2020'),
    { ...hit('tt0116191', 'Emma', '1996'), in_library: true },
  ]);
  assert.deepEqual(inLibrary.map((item) => item.id), ['tt0116191', 'tt9214832']);
});
