import Navbar from "@/components/landing/navbar";
import Hero from "@/components/landing/hero";
import Features from "@/components/landing/features";
import Why from "@/components/landing/why";
import Footer from "@/components/landing/footer";

export default function Home() {
  return (
    <>
      <Navbar />
      <Hero />
      <Features />
      <Why />
      <Footer />
    </>
  );
}