import { initializeApp } from "firebase/app";
import { collection, getDocs, deleteDoc, doc, getFirestore } from "firebase/firestore";
// 1. Paste your Firebase configuration here
// You can find this in your Firebase Console under Project Settings -> General
const firebaseConfig = {
  apiKey: "AIzaSyDS7GpZjoEvTJpj2GgPcXU6PQXz0Xa-P9I",
  authDomain: "kiakiapenang-fyp.firebaseapp.com",
  projectId: "kiakiapenang-fyp",
  storageBucket: "kiakiapenang-fyp.appspot.com",
  messagingSenderId: "152568659819",
  appId: "1:152568659819:web:52173f3ac1117dd0d5162e"
};

// 2. Initialize Firebase and Firestore
const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

// import { collection, getDocs, deleteDoc, doc } from "firebase/firestore";
// // Make sure to import your 'db' instance here

async function removeDuplicates() {
  console.log("Scanning for duplicates...");
  const stampsCollectionRef = collection(db, "stamps");
  
  try {
    const snapshot = await getDocs(stampsCollectionRef);
    const seenNames = new Set();
    let deleteCount = 0;

    for (const document of snapshot.docs) {
      const stampName = document.data().stampName;

      // If we have already seen this stampName, it's a duplicate
      if (seenNames.has(stampName)) {
        const docRef = doc(db, "stamps", document.id);
        await deleteDoc(docRef);
        console.log(`🗑️ Deleted duplicate: ${stampName} (ID: ${document.id})`);
        deleteCount++;
      } else {
        // First time seeing this name, add it to our tracking Set
        seenNames.add(stampName);
      }
    }
    
    console.log(`✅ Cleanup complete. Deleted ${deleteCount} duplicate entries.`);
  } catch (error) {
    console.error("❌ Error cleaning up duplicates:", error);
  }
}

// Execute the cleanup
removeDuplicates();