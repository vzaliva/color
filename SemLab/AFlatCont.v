(**
CoLoR, a Coq library on rewriting and termination.
See the COPYRIGHTS and LICENSE files.

- Frederic Blanqui, 2009-07-02

flat context closure (Sternagel & Middeldorp, RTA'08)
*)

Set Implicit Arguments.

Require Import ATrs.
Require Import NatUtil.
Require Import LogicUtil.
Require Import ListUtil.
Require Import SN.
Require Import EqUtil.
Require Import VecUtil.
Require Import Max.

Section S.

Variable Sig : Signature.

Notation term := (term Sig). Notation terms := (vector term).
Notation rule := (rule Sig). Notation rules := (rules Sig).

Lemma flat_cont_aux : forall n i, i < n -> i + S (n - S i) = n.

Proof.
intros. omega.
Qed.

Definition flat_cont_symb n (f : Sig) i (h : i < arity f) :=
  Cont f (flat_cont_aux h) (fresh n i) Hole (fresh (n+i) (arity f - S i)).

Definition flat_conts_symb n f :=
  map (fun x => flat_cont_symb n f (prf x)) (@nats_lt (arity f)).

Variable Fs : list Sig.
Variable Fs_ok : forall x : Sig, In x Fs.

Definition flat_conts n := flat_map (flat_conts_symb n) Fs.

Definition flat_cont_rule (a : rule) c :=
  let (l,r) := a in mkRule (fill c l) (fill c r).

Definition is_root_preserving (a : rule) := let (l,r) := a in
  match l, r with
    | Fun f _, Fun g _ => beq_symb f g
    | _, _ => true
  end.

Definition flat_rule n (a : rule) :=
  if is_root_preserving a then a :: nil
    else map (flat_cont_rule a) (flat_conts n).

Variable R : rules. Let n := maxvar_rules R.

Notation R' := (flat_map (flat_rule (S n)) R).

Lemma root_preserving : forall a,
  is_root_preserving a = true -> In a R -> In a R'.

Proof.
intros. rewrite in_flat_map. exists a. intuition. unfold flat_rule. rewrite H.
simpl. auto.
Qed.

Variable one_symbol : Sig.
Variable hyp : arity one_symbol > 0.

Definition one_flat_cont := flat_cont_symb n one_symbol hyp.

Lemma WF_flat : WF (red R) <-> WF (red R').

Proof.
split; intro.
(* -> *)
intro t. generalize (H t). induction 1. apply SN_intro; intros. apply H1.
redtac. rewrite in_flat_map in lr. destruct lr as [[a b] [h1 h2]].
unfold flat_rule in h2. simpl in h2.
destruct a. simpl in h2. intuition. inversion H2. subst. apply red_rule. hyp.
destruct b. simpl in h2. intuition. inversion H2. subst. apply red_rule. hyp.
gen h2. case_symb_eq Sig f f0; intro. simpl in h2. intuition. inversion H2.
subst. apply red_rule. hyp. rewrite in_map_iff in h2.
destruct h2 as [d [h3 h4]]. unfold flat_cont_rule in h3. inversion h3.
clear h3. subst. unfold flat_conts in h4. rewrite in_flat_map in h4.
destruct h4 as [g [h5 h6]]. unfold flat_conts_symb in h6.
rewrite in_map_iff in h6. destruct h6 as [x [h3 h4]]. subst.
unfold flat_cont_symb. simpl. repeat rewrite Vmap_cast.
repeat rewrite Vmap_app. simpl. set (v1 := Vmap (sub s) (fresh (S n) (val x))).
set (v2 := Vmap (sub s) (fresh (S(n+val x)) (arity g - S (val x)))).
set (e := flat_cont_aux (prf x)). set (d' := Cont g e v1 Hole v2).
set (v' := Vmap (sub s) v). set (v0' := Vmap (sub s) v0).
change (red R (fill c (fill d' (sub s (Fun f v))))
           (fill c (fill d' (sub s (Fun f0 v0))))). repeat rewrite fill_fill.
apply red_rule. hyp.
(* <- *)
intro t. geneq H t (fill one_flat_cont t). induction 1. intros. subst.
apply SN_intro; intros. apply H0 with (fill one_flat_cont y). 2: refl.
redtac. subst. repeat rewrite fill_fill.
case_eq (is_root_preserving (mkRule l r)). apply red_rule. rewrite in_flat_map.
exists (mkRule l r). intuition. unfold flat_rule. rewrite H1. simpl. auto.
destruct l. discr. destruct r. discr.
destruct (cont_case (comp one_flat_cont c)). discr.
destruct H2 as [d [g [i [vi [j [vj [e]]]]]]]. repeat rewrite H2.
repeat rewrite <- fill_fill. set (l := Fun f v). set (r := Fun f0 v0).
apply context_closed_red.
assert (m : maxvar_rule (mkRule l r) < S n). eapply maxvar_rules_elim.
apply lr. unfold n. omega.
repeat rewrite fill_sub with (n:=n).
set (s' := maxvar_union (S n) s (fsub n (Vapp vi vj))).
apply hd_red_incl_red. apply hd_red_rule. rewrite in_flat_map.
exists (mkRule l r). intuition. unfold flat_rule. unfold l, r. rewrite H1.
rewrite in_map_iff. assert (h : i < arity g). omega.
exists (flat_cont_symb (S n) g h). intuition. simpl.
generalize (flat_cont_aux h). assert (arity g - S i = j). omega. rewrite H3.
intro. assert (e0=e). apply eq_unique. subst. refl.
unfold flat_conts. rewrite in_flat_map. exists g. split. apply Fs_ok.
unfold flat_conts_symb. rewrite in_map_iff. exists (mk_nat_lt h). intuition.
apply nats_lt_complete.
transitivity (maxvar_rule (mkRule l r)). omega. apply le_max_r.
transitivity (maxvar_rule (mkRule l r)). omega. apply le_max_l.
Qed.

End S.