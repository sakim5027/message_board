
const { test, before, beforeEach, after } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');

const {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  serverTimestamp,
} = require('firebase/firestore');

let testEnv;

// Create message data using our Message Board fields.
function makeMessage(uid, text = 'Hello from test') {
  return {
    authorUid: uid,
    authorName: 'Alice',
    text: text,
    createdAt: serverTimestamp(),
    editedAt: null,
  };
}

// Add a test message owned by Alice.
// This is only test setup in the local emulator.
async function seedAliceMessage() {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();

    await setDoc(
      doc(db, 'messages', 'alice-message'),
      makeMessage('alice')
    );
  });
}

// Start the test environment and load our security rules.
before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-message-board-rules',
    firestore: {
      host: '127.0.0.1',
      port: 8080,
      rules: fs.readFileSync(
        path.join(__dirname, '..', 'firestore.rules'),
        'utf8'
      ),
    },
  });
});

// Clear test data before each test.
beforeEach(async () => {
  await testEnv.clearFirestore();
});

// Clean up after testing.
after(async () => {
  if (testEnv) {
    await testEnv.cleanup();
  }
});

// TEST 1: Signed-out users cannot read messages.
test('Signed-out read is denied', async () => {
  await seedAliceMessage();

  const guest = testEnv.unauthenticatedContext();
  const db = guest.firestore();

  await assertFails(
    getDoc(doc(db, 'messages', 'alice-message'))
  );
});

// TEST 2: Bob cannot edit Alice's message.
test('Cross-UID update is denied', async () => {
  await seedAliceMessage();

  const bob = testEnv.authenticatedContext('bob');
  const db = bob.firestore();

  await assertFails(
    updateDoc(doc(db, 'messages', 'alice-message'), {
      text: 'Unauthorized edit',
      editedAt: serverTimestamp(),
    })
  );
});

// TEST 3: Bob cannot create a message using Alice's UID.
test('Forged authorUid create is denied', async () => {
  const bob = testEnv.authenticatedContext('bob');
  const db = bob.firestore();

  await assertFails(
    setDoc(
      doc(db, 'messages', 'forged-message'),
      makeMessage('alice', 'Fake message')
    )
  );
});

// TEST 4: Alice can create, read, edit, and delete
// her own message.
test('Correct-author CRUD is allowed', async () => {
  const alice = testEnv.authenticatedContext('alice');
  const db = alice.firestore();

  const messageRef = doc(db, 'messages', 'my-message');

  // CREATE
  await assertSucceeds(
    setDoc(messageRef, makeMessage('alice'))
  );

  // READ
  const created = await assertSucceeds(
    getDoc(messageRef)
  );

  assert.equal(created.exists(), true);

  // UPDATE
  await assertSucceeds(
    updateDoc(messageRef, {
      text: 'Edited by Alice',
      editedAt: serverTimestamp(),
    })
  );

  const updated = await getDoc(messageRef);
  assert.equal(updated.data().text, 'Edited by Alice');

  // DELETE
  await assertSucceeds(
    deleteDoc(messageRef)
  );

  const deleted = await getDoc(messageRef);
  assert.equal(deleted.exists(), false);
});
