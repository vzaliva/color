(**
CoLoR, a Coq library on rewriting and termination.
See the COPYRIGHTS and LICENSE files.

- Adam Koprowski, 2009-03-24

A termination solver using the polynomial interpretations method.
*)

Require Import Program.
Require Import ListUtil.
Require Import ListForall.
Require Import LogicUtil.
Require Import ZUtil.
Require Import VecUtil.
Require Import Problem.
Require Import ATrs.
Require Import SN.
Require Import APolyInt.
Require Import Polynom.
Require Import RelUtil.
Require Import MonotonePolynom.
Require Import PositivePolynom.
Require Import NaryFunction.
Require Import MonAlgChecker.
Require Import IntBasedChecker.
Require Import Proof.
Require Import ExcUtil.
Require Import AWFMInterpretation.

Set Implicit Arguments.

Section PolySolver.

Variable Sig : Signature.

(***********************************************************************)
(** checking polynomial interpretation and converting it to dependently
    typed interpretation with constraints *)

Program Definition check_mono (n : nat) (m : monomial) : Exc (Z * monom n) :=
  match m with
  | (coef, vars) =>
      match eq_nat_dec n (List.length vars) with
      | left _ => value (coef, vec_of_list vars)
      | right _ => error
      end
  end.

Definition check_poly (n : nat) (p : polynomial) : Exc (poly n) :=
  map_exc (@check_mono n) p.

Definition polyInt n := { p : poly n | pweak_monotone p }.

Notation symPI := (symInt Sig polyInt).

Program Definition symbol_poly_int (f : Sig) (p : polynomial) : Exc symPI :=
  match check_poly (arity f) p with
  | error => error
  | value fi => 
      match pweak_monotone_check fi with
      | error => error
      | value _ => value (buildSymInt Sig polyInt f fi)
      end
  end.

Definition defaultPoly n : poly n :=
  pconst n 1 ++ list_of_vec (Vbuild (fun i (ip : i < n) => (1%Z, mxi ip))).

Lemma defaultPoly_mxi_1 n i (H : i < n) : In (1%Z, mxi H) (defaultPoly n).

Proof.
  intros. right. simpl.
  apply list_of_vec_in.
  rewrite <- (Vbuild_nth (fun i (ip : i < n) => (1%Z, mxi ip)) H).
  apply Vnth_in.
Qed.

Lemma defaultPoly_wm n : pweak_monotone (defaultPoly n).

Proof with simpl; auto with zarith.
  intros. split... 
  apply lforall_intro. intros.
  ded (in_list_of_vec H).
  ded (Vbuild_in (fun i ip => (1%Z, mxi ip)) x H0).
  decomp_hyps. subst...
Qed.

Lemma defaultPoly_sm n : pstrong_monotone (defaultPoly n).

Proof.
  split. apply defaultPoly_wm.
  intros. 
  assert (HH : In (1%Z, mxi H) (defaultPoly n)).
  apply defaultPoly_mxi_1.
  set (w := coefPos_geC (defaultPoly n) (mxi H) 1 (defaultPoly_wm n) HH).
  auto with zarith.
Qed.

Program Definition defaultInt n : polyInt n := defaultPoly n.

Next Obligation.
Proof.
  set (w := defaultPoly_wm). simpl in w. apply w.
Qed.

Program Definition interpret n (fi : polyInt n) : naryFunction1 D n :=
  @peval_D n fi _.

Next Obligation.
Proof.
  destruct fi. hyp.
Qed.

(***********************************************************************)
(** weak and strong monotonicity checking *)

Program Definition poly_wm (fi : symPI) := True.
Program Definition poly_sm (fi : symPI) := pstrong_monotone (projT2 fi).

Lemma sm_imp_wm (fi : symPI) : poly_sm fi -> poly_wm fi.

Proof.
  firstorder.
Qed.

Program Definition check_wm (fi : symPI) : Exc (poly_wm fi) := 
  value _.

Next Obligation.
Proof.
  firstorder.
Qed.

Lemma wm_ok : forall fi, poly_wm fi -> Vmonotone1 (interpret (projT2 fi)) Dge.

Proof.
  intros. apply Vmonotone_transp. apply coef_pos_monotone_peval_Dle.
Qed.

Program Definition check_sm (fi : symPI) : Exc (poly_sm fi) :=
  pstrong_monotone_check (projT2 fi).

Lemma sm_ok : forall fi, poly_sm fi -> Vmonotone1 (interpret (projT2 fi)) Dgt.

Proof.
  intros. apply Vmonotone_transp. 
  apply pmonotone_imp_monotone_peval_Dlt. hyp. 
Qed.

Let buildSymInt := buildSymInt Sig polyInt.
Let defaultIntForSymbol := defaultIntForSymbol Sig polyInt defaultInt.

Lemma default_sm : forall f, poly_sm (buildSymInt (defaultIntForSymbol f)).

Proof.
  intros. apply defaultPoly_sm.
Qed.

Definition wm_spec := Build_monSpec interpret poly_wm check_wm wm_ok.
Definition sm_spec := Build_monSpec interpret poly_sm check_sm sm_ok.

(***********************************************************************)
(** rule compatibility with orders. *)

Section Orders.

Variable i : forall f : Sig, polyInt (arity f).

Definition I := makeI Sig D0 polyInt interpret i.

Let succ := IR I Dgt.
Let succeq := IR I Dge.

Program Definition check_succ (r : rule Sig) : Exc (succ (lhs r) (rhs r)) :=
  match coef_pos_check (rulePoly_gt i r) with
  | error => error
  | value _ => value _
  end.

Next Obligation.
Proof with try discriminate; auto.
  destruct_call coef_pos_check...
  apply pi_compat_rule...
Qed.

Program Definition check_succeq (r : rule Sig) : Exc (succeq (lhs r) (rhs r)) :=
  match coef_pos_check (rulePoly_ge i r) with
  | error => error
  | value _ => value _
  end.

Next Obligation.
Proof with try discriminate; auto.
  destruct_call coef_pos_check...
  apply pi_compat_rule_weak...
Qed.

End Orders.

(***********************************************************************)
(** solver for the technique of polynomial interpretations. *)

Section solver.

Variable int : rawTrsInt Sig polynomial.

Definition succ_WF := WF_Dgt.

Lemma succ_succeq_compat : absorb Dgt Dge.

Proof.
  intros p q pq. destruct pq as [r [pr rq]].
  unfold Dgt, Dlt, transp. apply Zlt_le_trans with (val r); auto.
Qed.

Program Definition polySolver := monotoneAlgebraSolver succ_WF 
  succ_succeq_compat defaultInt check_succ check_succeq wm_spec sm_spec 
  sm_imp_wm default_sm int symbol_poly_int.

End solver.

End PolySolver.
