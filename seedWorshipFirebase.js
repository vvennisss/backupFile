import { initializeApp } from "firebase/app";
import { getFirestore, collection, addDoc } from "firebase/firestore";

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

// 3. Your Data Array
const worshipPlacesData = [
  {
    stampName: "Goddess of Mercy Temple",
    stampImage: "https://github.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/blob/master/stampsimages/Goddess%20of%20Mercy%20Temple.jpg",
    stampInformation: "Built in 1728, the Goddess of Mercy Temple (Kuan Yin Teng) is Penang's oldest Taoist temple. It was originally established jointly by early Hokkien and Cantonese settlers and dedicated to Mazu (Goddess of the Sea) for safe passage. As the community settled, the primary focus shifted to Kuan Yin (Goddess of Mercy). According to local lore, the temple is divinely protected; it miraculously survived multiple historical fires and the 1941 WWII Japanese bombings completely unscathed, serving as a safe haven for terrified locals seeking shelter."
  },
  {
    stampName: "Kapitan Keling Mosque",
    stampImage: "https://github.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/blob/master/stampsimages/Kapitan%20Keling%20Mosque.jpg",
    stampInformation: "Built in 1801, this magnificent mosque was founded by the first Indian Muslim settlers (Chulias) under the leadership of Cauder Mohudeen, who was appointed as the 'Kapitan Keling' (headman of the Indian community) by the British. Featuring striking Mughal architecture, black domes, and a towering minaret used for the call to prayer, it underwent major expansions in the 1930s. For over two centuries, it has stood as the vibrant spiritual, social, and economic nucleus of Penang's Indian Muslim community."
  },
  {
    stampName: "Sri Mahamariamman Temple",
    stampImage: "https://github.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/blob/master/stampsimages/Sri%20Mahamariamman%20Temple.jpg",
    stampInformation: "Established in 1833, this is the oldest Hindu temple in Penang, nestled in the heart of George Town's Little India. It originated as a humble shrine built by Indian stevedores and laborers working at the Penang port. Today, it is famous for its magnificent 23.6-foot-tall gopuram (entrance tower), built in 1933, which features 38 intricately carved statues of Hindu deities. The temple holds great cultural significance as it is the traditional starting point for Penang's grand annual Thaipusam chariot procession."
  },
  {
    stampName: "St George's Church",
    stampImage: "https://github.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/blob/master/stampsimages/St%20George's%20Church.jpg",
    stampInformation: "Built in 1818 and consecrated in 1819, St George's Church is the oldest purpose-built Anglican church in Southeast Asia. Designed by Captain Robert Smith, it boasts elegant Neoclassical and Georgian architecture with distinct Doric columns. The pristine grounds also house a memorial pavilion dedicated to Captain Francis Light, the founder of the British settlement in Penang. The church suffered severe damage and looting during the Japanese occupation in WWII, but was meticulously restored and rightfully declared a Malaysian National Heritage site in 2007."
  }
];

// 4. The Upload Function
async function uploadStampData() {
  console.log("Starting upload to Firestore...");
  
  // Reference to the 'stamps' collection in your database
  const stampsCollectionRef = collection(db, "stamps");

  for (const stamp of worshipPlacesData) {
    try {
      // addDoc automatically generates a unique ID for each document
      const docRef = await addDoc(stampsCollectionRef, stamp);
      console.log(`✅ Successfully added: ${stamp.stampName} (ID: ${docRef.id})`);
    } catch (error) {
      console.error(`❌ Error adding ${stamp.stampName}: `, error);
    }
  }
  
  console.log("🎉 All stamp data uploaded successfully!");
}

// 5. Execute the function
uploadStampData();