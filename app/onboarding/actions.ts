"use server";

import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

function slugify(text: string) {
  return text
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/(^-|-$)/g, "");
}

export async function createBusiness(formData: FormData) {
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  const name = formData.get("name")?.toString() ?? "";
  const industry = formData.get("industry")?.toString() ?? "";

  const slug = slugify(name);

  // Création du commerce
  const { data: business, error } = await supabase
    .from("businesses")
    .insert({
      name,
      slug,
      industry
    })
    .select()
    .single();

  if (error) {
    console.error(error);
    throw new Error("Impossible de créer le commerce.");
  }

  // Création du lien utilisateur <-> commerce
  const { error: membershipError } = await supabase
    .from("memberships")
    .insert({
      profile_id: user.id,
      business_id: business.id,
      role: "owner",
    });

  if (membershipError) {
    console.error(membershipError);
    throw new Error("Impossible de créer les droits.");
  }

  redirect("/dashboard");
}