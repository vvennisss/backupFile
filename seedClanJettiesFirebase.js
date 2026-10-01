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
const jettiesData = [
  {
    stampName: "Ong Jetty",
    stampImage: "https://github.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/blob/master/stampsimages/Ong%20Jetty.jpg",
    stampInformation: "Ong Jetty (姓王桥) is the first jetty encountered when moving south from Raja Tun Uda Ferry Terminal along Weld Quay. Unlike other clan jetties, Ong Jetty was never developed into a residential stilt settlement and maintains its original working function. Built by Ong clan members originating from Luanmeishe (Tong An District, Quanzhou, Fujian), it originally stood where the current ferry terminal is located. Today, its historic sheds serve primarily as motorcycle parking with an extended wooden pier jutting into the sea next to the Penang Port Commission building."
  },
  {
    stampName: "Lim Jetty",
    stampImage: "https://github.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/blob/master/stampsimages/Lim%20Jetty.jpg",
    stampInformation: "Lim Jetty (姓林桥) was founded by settlers from Houcunzhuang (Tong An, Quanzhou, Fujian). Prior to WWII, it was a bustling settlement with 42 buildings, but was tragically destroyed by Japanese air bombings in December 1941. Rebuilt post-war into 30 stilt houses with zinc roofs, it houses several significant temples: Ri Yue Than (Sun Moon Temple, built in 1976) which hosts an annual Mazu birthday sea procession across the Butterworth channel; Suan Hai Ing Yang Tian (Mountain Sea Ying-Yang Temple), honoring Taiseh-yah (God of Hades) with Hungry Ghost Festival bonfires; and Wu Gu Xian Zu Shrine with coin-shaped windows dedicated to the God of Herbs Shennong."
  },
  {
    stampName: "Chew Jetty",
    stampImage: "https://github.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/blob/master/stampsimages/Chew%20Jetty.jpg",
    stampInformation: "Chew Jetty (姓周桥) is the largest and most famous water village among the Clan Jetties, with 75 buildings established by clansmen from Xinglinshe (Tong An, Quanzhou, Fujian). Spared from the destruction of WWII, the jetty thrived as a boat shuttle hub for cargo ships and sailors. It is renowned for its grand annual 'Thi Kong Seh' (Jade Emperor's Birthday) celebration on the 9th day of Chinese New Year with a 50-meter altar table, roast pigs, and midnight fireworks. The jetty also features Chao Yuan Kong (Temple of Good Health), Kang Thean Kong (Temple of God's Blessings facing the sea), and an interpretative Community Hall."
  },
  {
    stampName: "Tan Jetty",
    stampImage: "https://github.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/blob/master/stampsimages/Tan%20Jetty.jpg",
    stampInformation: "Tan Jetty (姓陈桥) was founded by fishermen and oyster harvesters from Bingzhoushe (Tong An, Quanzhou, Fujian). Originally dwelling in Armenian Street kongsi houses, the clansmen erected stilts on Weld Quay to tie their sampans, expanding to 5 residential sheds by 1917. The jetty houses Chow Eng Tien (established in 1917, honoring Tang Dynasty General Tan Guan Kwong) where devotees seek spiritual guidance, and a long solitary timber pier leading to a Mazu Temple. It also serves as the sacred send-off point for the Nine Emperor Gods festival boat."
  },
  {
    stampName: "Lee Jetty",
    stampImage: "https://github.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/blob/master/stampsimages/Lee%20Jetty.jpg",
    stampInformation: "Lee Jetty (姓李桥) was established by settlers from Duishancun (Tong An, Quanzhou, Fujian) who started out as port coolies living along 'Sampan Lane'. Originally situated at the ferry terminal site, the community was relocated in the early 1960s to build their present jetty of 24 buildings. Historical boatmen disputes were resolved via gentleman agreements for shuttle routes. Its Kim Aun San Si Temple (1972) honors the Baosheng God of Health and houses a historic statue of Child Prince Nazha that was saved from China during the Cultural Revolution."
  },
  {
    stampName: "Mixed Surname Jetty (New Jetty)",
    stampImage: "https://github.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/blob/master/stampsimages/Mixed%20Surname%20Jetty%20(New%20Jetty).jpg",
    stampInformation: "Mixed Surname Jetty / New Jetty (杂姓桥) was founded in 1962 to accommodate families of mixed surnames, many branching out from Chew Jetty. Unlike single-clan jetties, it was constructed under strict municipal town planning regulations, featuring uniform layouts and vintage 1960s window grilles across 20 buildings. Two houses were dismantled when the underwater mainland-to-island water pipeline was laid. At the end of the boardwalk sits Kee Thean Keong (Temple of Heaven Ascension), venerating Xuantian God, Tua Pek Kong, and Dato' Kong."
  }
];

// 4. The Upload Function
async function uploadStampData() {
  console.log("Starting upload to Firestore...");
  
  // Reference to the 'stamps' collection in your database
  const stampsCollectionRef = collection(db, "stamps");

  for (const stamp of jettiesData) {
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