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
const heritagePlacesData = [
  {
    stampName: "Standard Chartered Building",
    stampImage: "https://github.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/blob/master/stampsimages/Standard%20Chartered%20Building.jpg",
    stampInformation: "Located in the heart of the Beach Street banking district, this imposing building was completed in 1930. Designed by the architectural firm Stark & McNeill, it features a blend of Palladian and Art Deco styles. As one of the oldest banks in Penang (the Chartered Bank of India, Australia and China first opened a branch here in 1875), it played a crucial role in financing the booming regional tin and rubber trades. Its sturdy, fortified design reflects its historical need to securely store vast amounts of physical wealth."
  },
  {
    stampName: "Pinang Peranakan Mansion",
    stampImage: "https://github.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/blob/master/stampsimages/Pinang%20Peranakan%20Mansion.jpg",
    stampInformation: "Built at the end of the 19th century, this vibrant green mansion originally served as 'Hai Kee Chan' (Sea Remembrance Store), the residence and office of Chung Keng Quee, a prominent Kapitan Cina and secret society leader. Although he was not a Baba himself, his home is a masterpiece of Straits Eclectic architecture, blending Chinese carved wood panels with English ceramic tiles and Scottish ironworks. Today, it has been meticulously restored into a museum showcasing over 1,000 antiques, offering a glimpse into the opulent lifestyle of the Peranakan (Baba Nyonya) community."
  },
  {
    stampName: "Nagore Durgha Shrine",
    stampImage: "https://github.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/blob/master/stampsimages/Nagore%20Durgha%20Shrine.jpg",
    stampInformation: "Built in the early 1800s by the Chulia Muslim community from southern India, this shrine is dedicated to Syed Abdul Kadir Al Hasan, a revered 13th-century saint from Nagore, India. It is not a tomb, but a memorial (dargha). The building features striking Southern Indian Islamic architecture with a miniature dome and minarets. For over two centuries, it has served as an important spiritual center for the Indian Muslim diaspora, historically providing a resting place and religious focus for arriving traders and laborers."
  },
  {
    stampName: "Malayan Railway Building",
    stampImage: "https://github.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/blob/master/stampsimages/Malayan%20Railway%20Building.jpg",
    stampInformation: "Built in 1907 by the Federated Malay States Railways (FMSR), this building has a famous quirk: it was a railway station that never saw a single train. Because the train tracks ended on the mainland in Butterworth, passengers would buy their tickets here, wait in the grand hall, and then board a railway ferry across the strait to catch their train. Now known as Wisma Kastam (Customs Building), its striking Edwardian Baroque architecture and prominent clock tower remain iconic waterfront landmarks."
  },
  {
    stampName: "India House",
    stampImage: "https://github.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/blob/master/stampsimages/India%20House.jpg",
    stampInformation: "Completed in 1937, India House is a striking example of early Art Deco architecture on Beach Street. It was built by a prominent Chettiar businessman, S.N.A.S.N.M. Somasundram, to serve the Indian merchant community. During WWII, the building was notably used by the Japanese forces, and post-war it housed the United States Information Service (USIS) library. Its distinct geometric façade and historical role highlight the economic influence of the South Indian mercantile class in colonial George Town."
  },
  {
    stampName: "Cheong Fatt Tze Mansion",
    stampImage: "https://github.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/blob/master/stampsimages/Cheong%20Fatt%20Tze%20Mansion.jpg",
    stampInformation: "Famously known as 'The Blue Mansion', this 1890s architectural marvel was built by Cheong Fatt Tze, a powerful Hakka merchant and diplomat known as the 'Rockefeller of the East'. Featuring 38 rooms, 5 granite courtyards, and 7 staircases, it was built in strict accordance with Feng Shui principles. The striking indigo-blue walls are made from a traditional lime wash mixed with the blue dye of the Indigofera tinctoria plant. Rescued from ruin in the 1990s, its restoration won the inaugural UNESCO Asia-Pacific Heritage Award for Culture Heritage Conservation in 2000."
  },
  {
    stampName: "Central Fire Station (Lebuh Pantai Fire Station)",
    stampImage: "https://github.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/blob/master/stampsimages/Central%20Fire%20Station%20(Lebuh%20Pantai%20Fire%20Station).jpg",
    stampInformation: "Built in 1908 at the junction of Beach Street and Chulia Street Ghaut, this is the oldest fire station still in operation in Penang. Its classical Mughal-influenced architecture is highlighted by a distinctive four-story watchtower. Before modern communication systems, firemen would take shifts at the top of this tower, scanning the George Town skyline for smoke to spot fires early. The building stands as a testament to the city's early efforts to protect its vital, densely-packed commercial warehouses."
  }
];

// 4. The Upload Function
async function uploadStampData() {
  console.log("Starting upload to Firestore...");
  
  // Reference to the 'stamps' collection in your database
  const stampsCollectionRef = collection(db, "stamps");

  for (const stamp of heritagePlacesData) {
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