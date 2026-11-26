import test from 'node:test'
import assert from 'node:assert/strict'
import { bloomWebReaderUrl } from '../src/lib/bloom-web-reader.ts'

const documentId = '7e09a2d3-f94c-47ac-82d6-8b64af1064e1'

test('builds the supported web reader route from a public HTTPS app origin', () => {
  assert.equal(
    bloomWebReaderUrl(documentId, 'https://bloom.example/'),
    `https://bloom.example/apps/read/reader/${documentId}`,
  )
})

test('allows loopback HTTP for local desktop development', () => {
  assert.equal(
    bloomWebReaderUrl(documentId, 'http://localhost:8081'),
    `http://localhost:8081/apps/read/reader/${documentId}`,
  )
})

test('rejects missing, non-HTTPS, credentialed, and path-prefixed origins', () => {
  assert.equal(bloomWebReaderUrl(documentId, undefined), null)
  assert.equal(bloomWebReaderUrl(documentId, 'http://bloom.example'), null)
  assert.equal(bloomWebReaderUrl(documentId, 'https://user@bloom.example'), null)
  assert.equal(bloomWebReaderUrl(documentId, 'https://bloom.example/app'), null)
})

test('rejects malformed document identifiers before building a route', () => {
  assert.equal(bloomWebReaderUrl('..%2Fsettings', 'https://bloom.example'), null)
  assert.equal(bloomWebReaderUrl('', 'https://bloom.example'), null)
})
