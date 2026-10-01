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
const monumentsData = [
  {
    stampName: "Queen Victoria Memorial Clock Tower",
    stampImage: "https://github.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/blob/master/stampsimages/Queen%20Victoria%20Memorial%20Clock%20Tower.jpg",
    stampInformation: "Located at the intersection of Light Street and Beach Street, the 97-foot tall Indo-Saracenic clock tower was built to commemorate the Diamond Jubilee of Queen Victoria in 1897. Financed entirely by Penang Chinese tycoon Cheah Chen Eok with a pledge of 30,000 British Trade Dollars, it was designed by Municipal Engineer Robert Peirce. The height is highly symbolic: each of its 60 feet from the base to the clock face represents a year of the Queen's reign. Although completed in 1902 after the Queen had passed away, it remains a defining George Town landmark, famously surviving WWII bombings with a slight, still-visible tilt."
  },
  {
    stampName: "Logan Memorial",
    stampImage: "https://github.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/blob/master/stampsimages/Logan%20Memorial.jpg",
    stampInformation: "Erected in 1873, the Logan Memorial honors James Richardson Logan, a Scottish lawyer who passionately championed the rights of Asians and non-Europeans in colonial Penang. Originally placed within the grounds of the Supreme Court, it now stands prominently across Light Street. The Gothic-styled monument features four allegorical female statues representing the Cardinal Virtues: Justice, Fortitude, Wisdom, and Temperance. According to local lore, it was strategically placed to remind judges and lawyers entering the High Court to always uphold the rule of law. (James Logan is also famously credited as the first person to publish the term 'Indonesia')."
  },
  {
    stampName: "Koh Seang Tat Fountain",
    stampImage: "https://github.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/blob/master/stampsimages/Koh%20Seang%20Tat%20Fountain.jpg",
    stampInformation: "Standing proudly at the junction of Esplanade Road and Light Street, the Municipal Fountain was donated to the Municipal Council in 1883 by Koh Seang Tat. He was a prominent Chinese millionaire, Justice of the Peace, and the grandson of Penang's first Kapitan Cina, Koh Lay Huan. The fountain was gifted in conjunction with the opening of the adjacent Town Hall. Meticulously restored to its original glory in 2011, it remains a fully functioning Victorian cast-iron fountain, serving as a beautiful testament to the philanthropic contributions of the early Chinese community toward George Town's civic infrastructure."
  },
  {
    stampName: "Francis Light Memorial",
    stampImage: "https://github.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/blob/master/stampsimages/Francis%20Light%20Memorial.jpg",
    stampInformation: "Located in the tranquil grounds of St. George's Church along Farquhar Street, this Georgian and Palladian-style memorial pavilion was erected to honor Captain Francis Light, the founder of the British settlement in Penang. While it is often mistakenly claimed to have been built for the 1886 centenary, historical records (including an 1848 sketch) indicate it was actually constructed in the early 1840s by Robert Scott. Beneath its domed roof, decorated with ornamental vases, lies a marble plaque commemorating Light's death in 1794 and recognizing his pivotal role in establishing the island."
  },
  {
    stampName: "Cenotaph War Memorial",
    stampImage: "https://github.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/blob/master/stampsimages/Cenotaph%20War%20Memorial.jpg",
    stampInformation: "Facing the open civic space of the Esplanade seafront, the Cenotaph is a poignant war memorial originally erected in 1929 to commemorate Allied servicemen who perished in World War I. Funded through public subscriptions and unveiled on Armistice Day, the original monument was systematically dismantled by the Japanese during the WWII occupation to prevent its complete collapse after Allied bombings. In 1948, it was carefully reconstructed using the surviving original granite blocks. Today, it bears a dual legacy—honoring the fallen soldiers of two World Wars and serving as the traditional focal point for annual Remembrance Day observances."
  }
];

// 4. The Upload Function
async function uploadStampData() {
  console.log("Starting upload to Firestore...");
  
  // Reference to the 'stamps' collection in your database
  const stampsCollectionRef = collection(db, "stamps");

  for (const stamp of monumentsData) {
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