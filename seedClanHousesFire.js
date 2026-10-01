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
const clanHousesData = [
  {
    stampName: "Seh Tek Tong Cheah Kongsi",
    stampImage: "https://github.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/blob/master/stampsimages/Seh%20Tek%20Tong%20Cheah%20Kongsi.jpg",
    stampInformation: "Founded in 1810 by Cheah Yam, this is one of the oldest Hokkien clan associations in George Town. Tucked away on Armenian Street, its architecture is a fascinating testament to the Straits Chinese identity. Unlike purely traditional clan houses, Cheah Kongsi features a striking fusion of Southern Fujian design and European classical elements, including British lion statues, stucco finishing, and classical columns alongside traditional Chinese roof ridges. It originally served as an administration center, spiritual hub, and welfare organization for Cheah clansmen originating from Sek Tong village in China."
  },
  {
    stampName: "Ng See Kah Miew (Ng Ancestral Temple)",
    stampImage: "https://github.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/blob/master/stampsimages/Ng%20See%20Kah%20Miew.jpg",
    stampInformation: "Built in 1897 along King Street, Ng See Kah Miew serves as the ancestral temple for the Ng (Huang in Mandarin) clan. The temple is celebrated for its intricate timber carvings and highly ornamented roof ridges adorned with 'Chian Nien' (cut-and-paste porcelain shard art) depicting dragons and legendary figures. Historically, it provided a sanctuary and social networking hub for newly arrived Ng clansmen migrating from various districts in Guangdong and Fujian provinces, helping them secure lodging and employment."
  },
  {
    stampName: "Har Yang Sit Teik Tong Yeoh Kongsi",
    stampImage: "https://github.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/blob/master/stampsimages/Har%20Yang%20Sit%20Teik%20Tong%20Yeoh%20Kongsi.jpg",
    stampInformation: "Established in 1836, this clan house was founded by Yeoh clansmen from Har Yang village in Fujian. Located near the intersection of Chulia Street and Victoria Street, it was originally built right on the waterfront before extensive land reclamation pushed the shoreline outward. The Yeohs were heavily involved in Penang's early maritime trade. The temple building, constructed in the traditional courtyard layout, houses an exquisite main altar dedicated to the patron deity, Chye Tian Tai Seng (The Monkey God), alongside the clan's ancestral tablets."
  },
  {
    stampName: "Eng Chuan Tong Tan Kongsi",
    stampImage: "https://github.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/blob/master/stampsimages/Eng%20Chuan%20Tong%20Tan%20Kongsi.jpg",
    stampInformation: "Founded in 1878, the Tan Kongsi is located in a quiet enclave known as Seh Tan Court off Beach Street. It serves the Tan clan, one of the most prominent Chinese surnames in Penang. The kongsi is dedicated to their patron deity, Tan Goan-kong, a revered Tang Dynasty general who played a major role in developing the Fujian province. Historically, the Tan clansmen were heavily affiliated with the Red Flag secret society. Today, the heavily ornamented temple preserves magnificent gilded wood carvings and centuries-old ancestral tablets."
  },
  {
    stampName: "Boon San Tong Khoo Kongsi",
    stampImage: "https://github.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/blob/master/stampsimages/Boon%20San%20Tong%20Khoo%20Kongsi.jpg",
    stampInformation: "Established in 1878 on Victoria Street, Boon San Tong is a sub-clan house representing the 'Hai Kee' branch of the Khoo family from Sin Kang village, Fujian. While it is smaller and less famous than its grand cousin (Leong San Tong Khoo Kongsi), it boasts equally impressive craftsmanship. It was formed because the Khoo clan had grown so large and wealthy that various branches required their own administrative and spiritual centers. The building underwent a meticulous, award-winning restoration to preserve its authentic frescoes and gold-leaf timber carvings."
  },
  {
    stampName: "Leong San Tong Khoo Kongsi",
    stampImage: "https://github.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/blob/master/stampsimages/Leong%20San%20Tong%20Khoo%20Kongsi.jpg",
    stampInformation: "Widely considered the most magnificent clan house in Southeast Asia, Leong San Tong was founded in 1835 in Cannon Square. According to famous local lore, the clan's original 1894 complex was so extravagantly majestic that it provoked the jealousy of the gods, causing it to mysteriously burn down on the eve of its inauguration in 1901. A slightly scaled-down, yet still spectacular, version was completed in 1906. Built by master craftsmen imported from China, its roofs feature staggering 25-ton ceramic decorations, showcasing the immense wealth and power of the Khoo clan in colonial Penang."
  }
];

// 4. The Upload Function
async function uploadStampData() {
  console.log("Starting upload to Firestore...");
  
  // Reference to the 'stamps' collection in your database
  const stampsCollectionRef = collection(db, "stamps");

  for (const stamp of clanHousesData) {
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