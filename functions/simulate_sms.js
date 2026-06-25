// Simulation of the Cloud Function Logic
// This script mocks Firebase Admin to verify the logic flow

// MOCK DB
const mockDb = {
    collection: (path) => ({
        where: (field, op, val) => ({
            where: (f2, o2, v2) => ({
                get: async () => {
                    console.log(`[MOCK DB] Querying ${path} where ${field}${op}${val} AND ${f2}${o2}${v2}`);
                    // Simulate "Not Found" for new user
                    return { empty: true, docs: [] };
                }
            })
        }),
        doc: (id) => ({
            set: async (data, opts) => {
                console.log(`[MOCK DB] Setting doc ${path}/${id} with data:`, data);
            }
        })
    }),
    doc: (path) => ({
        set: async (data, opts) => {
            console.log(`[MOCK DB] Setting doc ${path} with data:`, data);
        }
    })
};

// MOCK RES
const mockRes = {
    status: (code) => ({
        set: (k, v) => ({
            send: (body) => {
                console.log(`[MOCK RES] Status: ${code}, Body: ${body}`);
            }
        }),
        send: (body) => {
            console.log(`[MOCK RES] Status: ${code}, Body: ${body}`);
        }
    })
};

// THE LOGIC (Copied/Adapted from index.js)
async function simulatedIncomingSMS(req, res) {
    const { Body, From } = req.body;
    
    if (!From) {
        return res.status(400).send("Missing 'From' number");
    }

    const phone = From.replace(/\D/g, ''); 
    const name = Body ? Body.trim() : "SMS Patient";

    console.log(`Processing SMS from ${phone} with body: ${Body}`);

    // 1. CHECK IF ALREADY IN QUEUE
    const qSnap = await mockDb.collection("queue") // Simplified path
      .where("phone", "==", phone)
      .where("status", "==", "waiting") 
      .get();

    if (!qSnap.empty) {
        return res.status(200).send("Already in queue");
    }

    // 2. REGISTER USER
    const userRef = mockDb.doc(`users/${phone}`);
    await userRef.set({
      phone: phone,
      name: name,
      isSMSUser: true
    }, { merge: true });

    // 3. ADD TO QUEUE
    const token = Math.floor(1000 + Math.random() * 9000);
    const queueRef = mockDb.collection("queue").doc(phone);
    
    await queueRef.set({
      patientId: phone,
      name: name,
      status: 'waiting',
      source: 'sms',
      token: token,
      phone: phone
    });

    const successMsg = `Welcome to MediQue! You are added to the queue. Your Token is #${token}.`;
    res.status(200).set('Content-Type', 'text/xml').send(`<Response><Message>${successMsg}</Message></Response>`);
}

// RUN THE SIMULATION
console.log("--- STARTING SMS SIMULATION ---");
simulatedIncomingSMS({
    body: {
        From: "+919876543210",
        Body: "Rahul Dravid"
    }
}, mockRes);
